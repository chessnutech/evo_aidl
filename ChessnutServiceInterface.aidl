// ChessnutServiceInterface.aidl
package com.chessnutech.chessnutevo;

import com.chessnutech.chessnutevo.ChessnutServiceChessnutVisionCallback;
import com.chessnutech.chessnutevo.ChessnutServiceChessBoardCallback;
import android.graphics.Bitmap;

interface ChessnutServiceInterface{
    //board
    String getFen();
    oneway void setLed(in boolean[] ledSwitches, in byte[] r, in byte[] g, in byte[] b);

    //vision
    oneway void chessDetect(in Bitmap imageBitmap, in String UUID);

    //callbacks
    //detection
    String registerChessnutVisionCallback(ChessnutServiceChessnutVisionCallback callback);
    void unregisterChessnutVisionCallback(ChessnutServiceChessnutVisionCallback callback);
    //fen
    void registerChessBoardCallback(ChessnutServiceChessBoardCallback callback);
    void unregisterChessBoardCallback(ChessnutServiceChessBoardCallback callback);
}