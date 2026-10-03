import QtQuick 2.15

Item {
    id: root
    width: 1
    height: 1
    Component.onCompleted: {
        var oldImportFailed = false;
        try {
            Qt.createQmlObject('import QtQuick 2.4; RegularExpressionValidator { regularExpression: /\\d{4,}/ }', root);
        } catch (error) {
            oldImportFailed = String(error).indexOf('RegularExpressionValidator is not a type') >= 0;
        }
        if (!oldImportFailed) throw new Error('Original import did not reproduce the reported failure');
        var input = Qt.createQmlObject('import QtQuick 2.14; TextInput { validator: RegularExpressionValidator { regularExpression: /\\d{4,}/ } }', root);
        var cases = [['123', false], ['1234', true], ['12345', true], ['12ab', false]];
        for (var i = 0; i < cases.length; ++i) {
            input.text = cases[i][0];
            if (input.acceptableInput !== cases[i][1]) throw new Error('Validator case failed: ' + i);
        }
        console.log('PASS: import 2.4 reproduces the failure; import 2.14 accepts valid PINs and rejects invalid ones');
        quitTimer.start();
    }
    Timer { id: quitTimer; interval: 1; onTriggered: Qt.quit() }
}
