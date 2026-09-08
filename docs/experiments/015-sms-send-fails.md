# 015 — `SendSMS Result: 0x8015` means a bad destination number, not a broken port

**Date:** 2026-09-08 · **Status:** ✅ resolved — SMS works. This entry exists so
nobody re-runs the investigation.

## What happened

Sending an SMS failed every time, with ofono reporting

```
ofonod: sms send error SYSTEM_ERR
```

and Samsung's RIL reporting

```
RILD2: DoSendSms():
RILD2: Use default SMSC. <carrier SMSC>
RILD2: IpcTxSendSms()
RILD2: SendSMS Result: 0x8015, Tp cause: 0xFF,
```

**The destination number had two digits transposed.** With the correct number
the very next send returned:

```
RILD2: SendSMS Result: 0x0, Tp cause: 0xFF,
```

So on this RIL:

| result | meaning |
|---|---|
| `0x8015` | the modem rejected the destination address |
| `0x0` | sent |

`Tp cause: 0xFF` throughout — there is no TP-layer cause because the message
never reached the network. That was the clue that the failure was local, and it
was read correctly and then attached to the wrong cause.

## How an hour went into a typo

Worth recording, because every step looked reasonable.

The failing number was taken from the device's own message history, from the
threads that had just failed — so it was the typo, and using it guaranteed the
error would reproduce. It even looked wrong at the time: its prefix is not a valid
German mobile block, while the other number in the same history has one
that is. That observation was made and then not acted on.

Four hypotheses were built on top of it and tested, all sound in themselves and
all irrelevant:

* **SMS over IMS failing on LTE, needing CS fallback.** Forced
  `TechnologyPreference=gsm`, confirmed re-registration on EDGE, sent again,
  identical `0x8015`. This correctly proved the failure was not
  radio-technology-dependent.
* **Wrong SMSC.** `MessageManager.ServiceCenterAddress` holds the carrier's
  SMS centre with type 145, and the RIL logs that it uses it. Correct.
* **Wrong `radioInterface` in `binder.conf`.** The port sets 1.4 and `lshal`
  confirms `android.hardware.radio@1.4::IRadio` is registered for both slots.
  The setting is correct.
* **Samsung's missing `seh` / IMS stack.** The RIL does log
  `sehRadioService[0]->mSehRadioIndication == NULL` and
  `mSehChannelCallback == NULL [imsd2]`, and those services genuinely are
  absent — no definitions in `/android/vendor/etc/init/`, because they live in
  Samsung's `/system` which Halium replaces. **This is real but is not related
  to SMS.** The RIL emits those lines constantly, including when nothing is
  being sent. It was the last anomaly standing, which is exactly why it looked
  like a cause.

**The lesson is the cheap check first.** Before diagnosing a transmit path,
send to a number known to be good. A test that reproduces the failure with the
same bad input is not evidence about anything else.

## What is still true and worth keeping

* `0x8015` vs `0x0` decoded above — useful the next time SMS misbehaves.
* Samsung's `seh`/IMS services really are absent, for the structural reason
  given. If something else turns out to need them, that is the explanation.
* `MessageManager.Bearer` cannot be changed: `SetProperty` returns
  `method return` and the value stays `cs-preferred`. A real, separate, minor
  bug — `cs-only` and `ps-only` are unreachable.
* **`dbus-send` without `--print-reply` swallows errors.** Every ofono setter
  looked like a no-op until the flag was added.
* **`SendMessage` returning an object path means queued, not sent.** The result
  arrives asynchronously and only the logs show it.
