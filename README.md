# Chessnut EVO Third-party App AIDL Integration Guide

This document explains how a third-party Android app running on Chessnut EVO can connect to the EVO chessboard service through AIDL, read the current physical-board FEN, register for FEN change callbacks, and control the board LEDs.

## Service Information

The EVO chessboard service is exported by the system Launcher app.

| Item | Value |
| --- | --- |
| Service package | `com.chessnutech.chessnutevo.launcher` |
| Service class | `com.chessnutech.chessnutevo.chessnutservice.ChessnutService` |
| AIDL package | `com.chessnutech.chessnutevo` |
| Main interface | `ChessnutServiceInterface` |
| FEN callback interface | `ChessnutServiceChessBoardCallback` |

Third-party apps should bind the service with an explicit `ComponentName`:

```java
new ComponentName(
        "com.chessnutech.chessnutevo.launcher",
        "com.chessnutech.chessnutevo.chessnutservice.ChessnutService"
)
```

No additional permission is required for the `getFen()`, FEN callback, or `setLed()` APIs described in this document.

## Integration Steps

### 1. Copy the AIDL Files

Copy the EVO AIDL files into the same relative path in the third-party app project:

```text
app/src/main/aidl/com/chessnutech/chessnutevo/ChessnutServiceInterface.aidl
app/src/main/aidl/com/chessnutech/chessnutevo/ChessnutServiceChessBoardCallback.aidl
app/src/main/aidl/com/chessnutech/chessnutevo/ChessnutServiceChessnutVisionCallback.aidl
```

Keep the AIDL `package`, interface names, and method order unchanged. Even if the third-party app only uses FEN and LED APIs, keep all three AIDL files so the generated Binder interface matches the EVO system service.

`ChessnutServiceInterface.aidl`

```aidl
package com.chessnutech.chessnutevo;

import com.chessnutech.chessnutevo.ChessnutServiceChessnutVisionCallback;
import com.chessnutech.chessnutevo.ChessnutServiceChessBoardCallback;
import android.graphics.Bitmap;

interface ChessnutServiceInterface {
    String getFen();
    oneway void setLed(in boolean[] ledSwitches, in byte[] r, in byte[] g, in byte[] b);

    oneway void chessDetect(in Bitmap imageBitmap, in String UUID);

    String registerChessnutVisionCallback(ChessnutServiceChessnutVisionCallback callback);
    void unregisterChessnutVisionCallback(ChessnutServiceChessnutVisionCallback callback);

    void registerChessBoardCallback(ChessnutServiceChessBoardCallback callback);
    void unregisterChessBoardCallback(ChessnutServiceChessBoardCallback callback);
}
```

`ChessnutServiceChessBoardCallback.aidl`

```aidl
package com.chessnutech.chessnutevo;

interface ChessnutServiceChessBoardCallback {
    oneway void onFenChanged(String fen);
}
```

`ChessnutServiceChessnutVisionCallback.aidl`

```aidl
package com.chessnutech.chessnutevo;

interface ChessnutServiceChessnutVisionCallback {
    oneway void onDetectionResult(
            in boolean valid,
            in float[] x,
            in float[] y,
            in float[] w,
            in boolean promote,
            in String fen,
            in int[] stars
    );
}
```

### 2. Enable AIDL Compilation

Enable AIDL in the third-party app module's `build.gradle`:

```gradle
android {
    buildFeatures {
        aidl true
    }
}
```

If the app needs to query whether the EVO Launcher package is installed on Android 11 or later, add this package visibility declaration to `AndroidManifest.xml`:

```xml
<queries>
    <package android:name="com.chessnutech.chessnutevo.launcher" />
</queries>
```

### 3. Bind the Service

```java
Intent intent = new Intent();
intent.setComponent(new ComponentName(
        "com.chessnutech.chessnutevo.launcher",
        "com.chessnutech.chessnutevo.chessnutservice.ChessnutService"
));

boolean ok = bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE);
```

Get the AIDL interface from `ServiceConnection`:

```java
private ChessnutServiceInterface chessnutService;

private final ServiceConnection serviceConnection = new ServiceConnection() {
    @Override
    public void onServiceConnected(ComponentName name, IBinder service) {
        chessnutService = ChessnutServiceInterface.Stub.asInterface(service);
    }

    @Override
    public void onServiceDisconnected(ComponentName name) {
        chessnutService = null;
    }
};
```

## API Reference

### Get the Current Physical-board FEN

```java
String fen = chessnutService.getFen();
```

The return value is the latest position reported by the EVO physical chessboard. The current API returns only the piece-placement field of FEN, for example:

```text
rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR
```

It does not include side to move, castling rights, en passant target square, halfmove clock, or fullmove number. When the chessboard service has just started and has not received board data yet, it may return an empty string.

### Register for FEN Change Callbacks

```java
chessnutService.registerChessBoardCallback(fenCallback);
```

When the physical board position changes, the service calls:

```java
private final ChessnutServiceChessBoardCallback fenCallback =
        new ChessnutServiceChessBoardCallback.Stub() {
            @Override
            public void onFenChanged(String fen) {
                // This runs on a Binder thread. Switch to the main thread before updating UI.
            }
        };
```

Unregister the callback when it is no longer needed:

```java
chessnutService.unregisterChessBoardCallback(fenCallback);
```

Note: `registerChessBoardCallback()` only registers future changes. It does not immediately push the current FEN. If the app needs the current position right after binding, call `getFen()` once after registering the callback.

### Set LEDs

```java
chessnutService.setLed(ledSwitches, r, g, b);
```

Parameters:

| Parameter | Type | Description |
| --- | --- | --- |
| `ledSwitches` | `boolean[64]` | `true` turns on the LED for the corresponding square, `false` turns it off |
| `r` | `byte[64]` | Red channel, raw value `0..255` |
| `g` | `byte[64]` | Green channel, raw value `0..255` |
| `b` | `byte[64]` | Blue channel, raw value `0..255` |

When `ledSwitches` is not `null`, `ledSwitches`, `r`, `g`, and `b` must all be non-null arrays with length `64`.

Turn off all LEDs:

```java
chessnutService.setLed(null, null, null, null);
```

LED array indexes are ordered from `a8` to `h1`:

```text
0  = a8,  1 = b8,  ...  7 = h8
8  = a7,  9 = b7,  ... 15 = h7
...
56 = a1, 57 = b1,  ... 63 = h1
```

Common square-index helper:

```java
private static int squareIndex(String square) {
    int file = square.charAt(0) - 'a'; // a..h -> 0..7
    int rank = square.charAt(1) - '0'; // 1..8
    return (8 - rank) * 8 + file;
}
```

LED state is global on the physical board. If multiple apps call `setLed()` at the same time, the latest call overwrites the previous LED state. Third-party apps should turn off the LEDs when leaving the relevant screen.

## Complete Java Example

The following example binds the EVO service, reads the current FEN, registers a FEN callback, lights `e4` in blue, and turns off all LEDs when the screen stops.

```java
package com.example.evoaidldemo;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.IBinder;
import android.os.RemoteException;
import android.util.Log;

import com.chessnutech.chessnutevo.ChessnutServiceChessBoardCallback;
import com.chessnutech.chessnutevo.ChessnutServiceInterface;

public class MainActivity extends Activity {
    private static final String TAG = "EvoAidlDemo";
    private static final String EVO_PACKAGE = "com.chessnutech.chessnutevo.launcher";
    private static final String EVO_SERVICE =
            "com.chessnutech.chessnutevo.chessnutservice.ChessnutService";

    private ChessnutServiceInterface chessnutService;
    private boolean bindRequested;

    private final ChessnutServiceChessBoardCallback fenCallback =
            new ChessnutServiceChessBoardCallback.Stub() {
                @Override
                public void onFenChanged(String fen) {
                    runOnUiThread(() -> Log.d(TAG, "FEN changed: " + fen));
                }
            };

    private final ServiceConnection serviceConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
            chessnutService = ChessnutServiceInterface.Stub.asInterface(service);

            try {
                chessnutService.registerChessBoardCallback(fenCallback);

                String currentFen = chessnutService.getFen();
                Log.d(TAG, "Current FEN: " + currentFen);

                setSquareLed("e4", 0, 120, 255);
            } catch (RemoteException e) {
                Log.e(TAG, "Failed to call EVO service", e);
            }
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            chessnutService = null;
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    protected void onStart() {
        super.onStart();

        Intent intent = new Intent();
        intent.setComponent(new ComponentName(EVO_PACKAGE, EVO_SERVICE));

        bindRequested = bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE);
        Log.d(TAG, "bindService result: " + bindRequested);
    }

    @Override
    protected void onStop() {
        if (chessnutService != null) {
            try {
                chessnutService.unregisterChessBoardCallback(fenCallback);
                chessnutService.setLed(null, null, null, null);
            } catch (RemoteException e) {
                Log.e(TAG, "Failed to release EVO service", e);
            }
        }

        if (bindRequested) {
            unbindService(serviceConnection);
            bindRequested = false;
        }

        chessnutService = null;
        super.onStop();
    }

    private void setSquareLed(String square, int red, int green, int blue)
            throws RemoteException {
        if (chessnutService == null) {
            return;
        }

        boolean[] switches = new boolean[64];
        byte[] r = new byte[64];
        byte[] g = new byte[64];
        byte[] b = new byte[64];

        int index = squareIndex(square);
        switches[index] = true;
        r[index] = toByteColor(red);
        g[index] = toByteColor(green);
        b[index] = toByteColor(blue);

        chessnutService.setLed(switches, r, g, b);
    }

    private static int squareIndex(String square) {
        int file = square.charAt(0) - 'a';
        int rank = square.charAt(1) - '0';
        return (8 - rank) * 8 + file;
    }

    private static byte toByteColor(int value) {
        return (byte) (Math.max(0, Math.min(255, value)) & 0xff);
    }
}
```

## Common Notes

- AIDL callbacks run on Binder threads, not on the UI thread.
- Handle `RemoteException` for every remote service call.
- If `bindService()` returns `false`, confirm that the app is running on EVO and that the service package and class names are correct.
- `getFen()` returns the physical board position only. It does not complete the full six-field FEN.
- `setLed()` writes to the physical board, so avoid unnecessary high-frequency updates.
- When the app exits or no longer needs LED hints, call `setLed(null, null, null, null)` to turn off all LEDs.
