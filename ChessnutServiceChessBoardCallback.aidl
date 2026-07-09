// ChessnutServiceChessBoardCallback.aidl
package com.chessnutech.chessnutevo;

// Declare any non-default types here with import statements

interface ChessnutServiceChessBoardCallback {
    oneway void onFenChanged(String fen);
}