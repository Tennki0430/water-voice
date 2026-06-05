# Water Voice — ランディングページ

`index.html` の静的1ファイル＋`assets/`（画像）だけで完結します。ビルド不要。

## ローカルで確認

```bash
open index.html        # ブラウザで直接開く
# もしくは簡易サーバー
python3 -m http.server 8080   # → http://localhost:8080
```

## 公開（デプロイ）

いずれも無料で公開できます。

### Vercel（推奨・最速）
```bash
npm i -g vercel
cd landing
vercel        # 初回はログイン → デプロイ先を選ぶだけ
vercel --prod # 本番公開
```

### GitHub Pages
リポジトリの Settings → Pages で、ブランチ `master` / フォルダ `/landing` を公開元に指定。

### Netlify
`landing/` フォルダをドラッグ&ドロップ（Netlify Drop）。

## 公開前に差し替えるもの

- ダウンロード／購入ボタンの `href="#"` → 実際の配布・決済リンク
- フッターの法的リンク → `legal/` の各ページ（公開URL）
- 価格（現状は予定値 ¥3,800）
- `assets/icon-1024.png` の OGP 画像（SNS共有時のサムネ）

## 今後の追加候補

- デモ動画（15秒）を hero に埋め込み（アプリ起動して画面収録 → mp4/webm）
- 実機スクリーンショットへの差し替え
