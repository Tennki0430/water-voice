# Water Voice 設計書（Design Spec）

作成日: 2026-05-31
更新日: 2026-05-31（macOS 26.5 へのアップデートに伴い Apple 純正スタックへ全面移行）
ステータス: ドラフト（ユーザーレビュー待ち）

## 概要

市販の音声入力アプリに匹敵する **macOS ネイティブ常駐ディクテーションアプリ**「**Water Voice**」を開発する。
グローバルホットキーを押している間にマイク音声を録音し、Apple の新 Speech API
（`SpeechAnalyzer` / `SpeechTranscriber`）で文字起こし、Apple Foundation Models
（オンデバイス LLM）で整形（句読点付け・フィラー除去・改行・誤認識修正）したうえで、
クリップボード経由で **任意の最前面アプリ**（メモ / Slack / ブラウザ等）に自動貼付する。

最大の特徴は **完全オンデバイス・API コストゼロ・プライバシー保持**。

## 動作環境

- MacBook Air M4 / 24GB RAM / macOS **Tahoe 26.5**（確認済み）
- Apple Silicon 必須（Apple Foundation Models 実行のため）

> 注: macOS 26 で利用可能になった Apple Foundation Models（オンデバイス LLM）および
> 新 Speech API（`SpeechAnalyzer` / `SpeechTranscriber`）を全面採用する。
> これにより Ollama 等の外部 LLM は不要となり、完全 Apple 純正・追加ダウンロード不要で動作する。

## 技術スタック

| 領域 | 採用技術 |
|---|---|
| 言語 / UI | Swift + SwiftUI（`MenuBarExtra` でメニューバー常駐） |
| 録音 | `AVAudioEngine` |
| 文字起こし | Apple Speech（`SpeechAnalyzer` + `SpeechTranscriber`、日本語ロケール対応。要 `AssetInventory` でモデルDL） |
| AI 整形 | Apple Foundation Models（`FoundationModels` フレームワーク、`SystemLanguageModel` / `LanguageModelSession`）。オンデバイス・API コストゼロ |
| テキスト流し込み | クリップボード保存 → Cmd+V 送信（`CGEvent`）→ 元クリップボード復元 |
| 配布形態 | Dock アイコンなし常駐（`Info.plist` の `LSUIElement = true`） |

## アーキテクチャ

各部品はプロトコルで定義し、単体テスト可能にする（依存はモックで差し替え可能）。

```
HotKeyMonitor   グローバルホットキー監視（押下 / 離す検知）
AudioRecorder   マイク録音（AVAudioEngine）
Transcriber     音声 → 生テキスト（SpeechAnalyzer/SpeechTranscriber）— protocol 化
Formatter       生テキスト → 整形テキスト（Foundation Models / LanguageModelSession）— protocol 化
TextInjector    クリップボード退避 → Cmd+V → クリップボード復元
SettingsStore   ホットキー / 言語 / 整形プロンプトの永続化（UserDefaults）
AppCoordinator  状態機械（idle → recording → transcribing → formatting → injecting → idle）
MenuBarUI       状態表示・設定・権限 / Apple Intelligence 利用可否の案内
```

### 状態機械（AppCoordinator）

```
idle ──(ホットキー押下)──> recording
recording ──(ホットキー離す)──> transcribing
transcribing ──(成功)──> formatting
transcribing ──(失敗)──> idle（通知）
formatting ──(成功 or モデル利用不可でスキップ)──> injecting
injecting ──(完了)──> idle
```

## データフロー（押している間だけ録音）

```
ホットキー押下 → 録音開始（メニューバー ● 点灯）
        離す → 録音停止
            → SpeechAnalyzer で文字起こし（生テキスト）
            → Foundation Models で整形（句読点・フィラー除去・改行・誤認識修正）
            → クリップボードへ保存
            → Cmd+V 自動送信（最前面アプリへ貼付）
            → 元クリップボード内容を復元
```

## フェーズ計画（ゴール = 常駐アプリ、まずコア検証から）

- **Phase 0 — 基盤**
  - Xcode プロジェクト雛形（SwiftUI / `LSUIElement`、macOS 26.0+ ターゲット）
  - 権限設定（マイク / 音声認識 / アクセシビリティ）の Info.plist + entitlements
  - **Foundation Models 利用可否チェック**（`SystemLanguageModel.default.availability`）
    - Apple Intelligence 有効化 / モデルDL状況を確認し、未対応時の導線を用意
  - **Speech モデルのセットアップ**（`AssetInventory` で日本語ロケールのアセットを確保）

- **Phase 1 — コア検証（最初の到達点）**
  - 録音 → SpeechAnalyzer 文字起こし → Foundation Models 整形 を **自アプリ内のテキスト表示** で確認
  - 形態（常駐/ホットキー/貼付）はまだ持たず、ボタン操作で検証

- **Phase 2 — 常駐 + ホットキー**
  - グローバルホットキー（押下中録音）
  - メニューバー常駐化（状態インジケータ）

- **Phase 3 — 流し込み**
  - クリップボード貼付 + Cmd+V 自動送信（任意アプリへ）
  - 元クリップボード復元

- **Phase 4 — 仕上げ**
  - 設定 UI（ホットキー変更 / 言語 / 整形プロンプト / カスタム辞書）
  - エラー導線・通知の整備

## エラー処理 / フォールバック

- **権限未許可**（マイク / 音声認識 / アクセシビリティ）→ メニューバーから「システム設定」へ誘導。
- **Foundation Models 利用不可**（Apple Intelligence 未有効 / モデル未DL / 非対応デバイス）→ 整形をスキップし、生テキストをそのまま貼付。通知で「設定 > Apple Intelligence を有効にしてください」と案内。
- **文字起こし失敗** → 通知して処理中断（idle に戻る）。
- **Cmd+V 送信失敗**（アクセシビリティ未許可）→ 通知で許可を案内。クリップボードには整形済みテキストが残るため手動貼付は可能。

## テスト方針

- 単体テスト: `Transcriber` / `Formatter` / `TextInjector` をモック化。
- 状態機械テスト: `AppCoordinator` の遷移（成功 / 各種失敗）を網羅。
- 手動 E2E: メモ / Slack / ブラウザへの貼付確認、権限フロー確認、Foundation Models 利用不可時のフォールバック確認。

## 未決事項 / 今後の検討

- 既定ホットキーの具体キー（例: 右 Option 長押し）は Phase 2 着手時に確定。
- 整形プロンプトの初期文面は Phase 1 で実テキストを見ながら調整。
