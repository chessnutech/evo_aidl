// ChessnutServiceChessnutVisionCallback.aidl
package com.chessnutech.chessnutevo;

// Declare any non-default types here with import statements

interface ChessnutServiceChessnutVisionCallback {
    oneway void onDetectionResult(in boolean valid, in float[] x, in float[] y, in float[] w, in boolean promote, in String fen, in int[] stars);
}