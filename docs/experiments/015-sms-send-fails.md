# 015 — SMS sending fails with SYSTEM_ERR

**Date:** 2026-09-08 · **Status:** 🔴 open, root cause narrowed but not found

## The question

Sending an SMS fails. Everything else about the modem works — registration,
signal, data, calls not yet tried. What is rejecting the message?

## What is observed

ofono, on every attempt:

```
ofonod: sms send error SYSTEM_ERR
```

and behind it, Samsung's RIL in the Android container:

```
RILD2: DoSendSms():
RILD2: Use default SMSC. 491710760000
RILD2: IpcTxSendSms()
RILD2: SendSMS Result: 0x8015, Tp cause: 0xFF,
RILD2: OnSendSmsDone():__
```

`Tp cause: 0xFF` means there is **no TP-layer cause** — the network is not
rejecting the message. The modem itself returns `0x8015` about 0.4–3 s after
the request. One attempt returned `0x802A` (`SMS_SEND_FAIL_RETRY`) instead.

## What has been ruled out

Each of these was a real hypothesis, tested and discarded.

| ruled out | how |
|---|---|
| **Wrong or missing SMSC** | `MessageManager.ServiceCenterAddress` is `"491710760000",145`, and the RIL logs `Use default SMSC. 491710760000`. Correct for Telekom Germany |
| **SMS over IMS failing on LTE, needing CS fallback** | Forced `TechnologyPreference=gsm`, confirmed the device re-registered on **EDGE**, and sent again: identical `0x8015`. It fails the same on 2G as on LTE |
| **Wrong radio HAL version in `binder.conf`** | The port sets `radioInterface = 1.4`; `lshal` shows the device registers `android.hardware.radio@1.4::IRadio` for both slots. The setting is right |
| **SIM problem** | `Present = true`, `PinRequired = none`, registered, `Strength` 40, data works |
| **A dead modem generally** | Registration, signal, technology switching, flight mode and a working LTE data context all function |

## The one real lead

Samsung's extended radio HAL is missing, and the RIL says so constantly:

```
RILC : stkSmsSendResultInd: sehRadioService[0]->mSehRadioIndication == NULL
RILD2: HalIoChannel::Write: mSehChannelImpl->mSehChannelCallback == NULL [imsd2]
RILD2: Can't send SSAC info to IMS
```

`seh` is Samsung Extended HAL. Nothing provides it here:

* `getprop init.svc.imsd`, `imsd2`, `sehradiomanager`, `vendor.sehradio`,
  `vendor.ims_rild` are all **empty** — the services are not defined.
* `grep -rlE '^service .*(imsd|sehradio|ims_rild)' /android/vendor/etc/init/`
  matches **nothing**.
* Only `cbd` (the CP boot daemon) is running from that family.

They are absent because they live in Samsung's `/system`, and Halium replaces
`/system` with the generic GSI. This is not something `init.disabled.rc` turned
off — unlike the audio HAL in [007](007-abox-firmware-too-early.md), which was
disabled and could simply be re-enabled. These binaries are not on the device
at all.

**Whether SMS on this RIL genuinely requires `seh` is unproven.** It is the only
anomaly left, and the messages are emitted on the SMS path, but the RIL also
emits them constantly when nothing is being sent.

## Not yet tested

* **Receiving** an SMS. If inbound works and only outbound fails, that isolates
  the transmit path and makes the `seh` theory much stronger or much weaker.
* Whether other Samsung Halium ports with the same missing `seh` stack have
  working SMS. If they do, `seh` is a red herring.
* `MessageManager.Bearer` could not be changed — `SetProperty` returns success
  and the value stays `cs-preferred`, so `cs-only` / `ps-only` were never
  actually exercised.

## Traps hit while investigating this

* **`dbus-send` without `--print-reply` swallows errors.** Every ofono
  `SetProperty` looked like a silent no-op until the flag was added; they had
  all been returning `method return`.
* **Check the reader before blaming the writer.** The first technology-switch
  run reported nothing changing. The setter was fine; the readback was mangled
  by shell quoting.
* **`SendMessage` returning an object path means queued, not sent.** Both test
  messages returned a path and both failed afterwards.
