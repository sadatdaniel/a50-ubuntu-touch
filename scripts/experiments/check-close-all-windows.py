#!/usr/bin/env python3
"""Compile the actual closeAllWindows body against synchronous-removal fixtures."""
from pathlib import Path
import os
import shlex
import subprocess
import sys
import tempfile

source = Path(sys.argv[1]).read_text()
start = source.index('void TopLevelWindowModel::closeAllWindows()')
end = source.index('\nbool TopLevelWindowModel::rootFocus()', start)
method = source[start:end]
harness = r'''
#include <QVector>
#include <QObject>
#include <QtGlobal>
#include <cassert>
#include <functional>
#include <cstdio>

struct Window {
    int number;
    std::function<void(Window*)> onClose;
    int id() const { return number; }
    void close() { auto action = onClose; action(this); }
};
struct TopLevelWindowModel {
    struct ModelEntry { Window* window; };
    QVector<ModelEntry> m_windowModel;
    QVector<int> visited;
    bool m_closingAllApps = false;
    int completed = 0;
    void closedAllWindows() { ++completed; }
    void closeAllWindows();
    int indexForId(int id) const {
        for (int i = 0; i < m_windowModel.size(); ++i)
            if (m_windowModel[i].window->id() == id) return i;
        return -1;
    }
    void remove(int id) {
        int index = indexForId(id);
        assert(index >= 0);
        Window* window = m_windowModel[index].window;
        m_windowModel.removeAt(index);
        delete window;
        if (m_closingAllApps && m_windowModel.isEmpty()) closedAllWindows();
    }
    void add(int id, std::function<void(Window*)> action) {
        m_windowModel.append(ModelEntry{new Window{id, action}});
    }
    ~TopLevelWindowModel() {
        for (auto entry : m_windowModel) delete entry.window;
    }
};
'''
cases = r'''
int main() {
    { // Empty model still completes once.
        TopLevelWindowModel model;
        model.closeAllWindows();
        assert(model.completed == 1);
    }
    { // Asynchronous clients: completion follows the last later removal.
        TopLevelWindowModel model;
        for (int id : {1, 2, 3}) model.add(id, [&](Window* w){ model.visited.append(w->id()); });
        model.closeAllWindows();
        assert(model.visited == QVector<int>({1, 2, 3}));
        assert(model.completed == 0);
        model.remove(3); model.remove(2); model.remove(1);
        assert(model.completed == 1);
    }
    { // Synchronous self-removal invalidates iteration over the live vector.
        TopLevelWindowModel model;
        for (int id : {1, 2, 3}) model.add(id, [&](Window* w){
            int id = w->id(); model.visited.append(id); model.remove(id);
        });
        model.closeAllWindows();
        assert(model.visited == QVector<int>({1, 2, 3}));
        assert(model.completed == 1);
    }
    { // Closing one app may also destroy another of its windows.
        TopLevelWindowModel model;
        for (int id : {1, 2, 3}) model.add(id, [&](Window* w){
            int id = w->id(); model.visited.append(id);
            if (id == 1) model.remove(2);
            model.remove(id);
        });
        model.closeAllWindows();
        assert(model.visited == QVector<int>({1, 3}));
        assert(model.completed == 1);
    }
    { // A newly created window is not part of the original close request.
        TopLevelWindowModel model;
        for (int id : {1, 2, 3}) model.add(id, [&](Window* w){
            int id = w->id(); model.visited.append(id);
            if (id == 1) model.add(4, [&](Window*){ assert(false); });
            model.remove(id);
        });
        model.closeAllWindows();
        assert(model.visited == QVector<int>({1, 2, 3}));
        assert(model.m_windowModel.size() == 1);
        assert(model.completed == 0);
        model.remove(4);
        assert(model.completed == 1);
    }
    puts("PASS: actual closeAllWindows handles empty, async, self/sibling removal and new windows");
}
'''
with tempfile.TemporaryDirectory(prefix='a50-close-all-') as directory:
    cpp = Path(directory) / 'test.cpp'
    binary = Path(directory) / 'test'
    cpp.write_text(harness + method + cases)
    flags = shlex.split(subprocess.check_output(
        ['pkg-config', '--cflags', '--libs', 'Qt5Core'], text=True))
    subprocess.run(['g++', '-std=c++17', '-fPIC', '-no-pie', '-g', '-O1',
                    '-fsanitize=address', '-fno-omit-frame-pointer',
                    str(cpp), '-o', str(binary), *flags], check=True)
    result = subprocess.run([str(binary)], env={**os.environ,
        'ASAN_OPTIONS': 'detect_leaks=0:halt_on_error=1'})
    sys.exit(result.returncode)
