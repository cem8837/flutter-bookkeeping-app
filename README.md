# 我的智慧記帳 APP（Flutter 練習）

這是一個 Flutter 記帳練習專案，包含首頁收支摘要、新增與刪除紀錄、分類統計，以及姓名與每月預算設定。第一次開啟會建立六筆範例收支，方便直接試用。

## 線上試用

GitHub Pages：<https://cem8837.github.io/flutter-bookkeeping-app/>

這是練習展示版，不是正式的財務管理服務。紀錄只儲存在目前瀏覽器的本機儲存空間，不會同步到伺服器或其他裝置；請勿輸入真實或敏感的財務資料。

## 專案檔案

- `lib/main.dart`：收支資料模型、首頁、收入／支出表單、分類統計、Drawer、篩選選單、個人設定與刪除動畫。
- `lib/shared_preferences_helper.dart`：讀寫記帳紀錄、使用者名稱與每月預算。
- `pubspec.yaml`：Flutter 專案與 `shared_preferences` 套件設定。
- `.github/workflows/deploy-pages.yml`：每次推送到 `main` 時，自動建置並發布 GitHub Pages。

## 在本機執行

請先安裝 Flutter SDK，再於專案資料夾執行：

```bash
flutter pub get
flutter run
```

要在本機產生 Web 版本，可以執行：

```bash
flutter build web
```

GitHub Pages 的部署會由 GitHub Actions 自動執行，並以 `/flutter-bookkeeping-app/` 作為網站路徑。

## 怎麼確認功能

第一次啟動時會自動建立六筆測試資料。首頁的總收入、總支出與剩餘金額都從資料清單計算；新增或刪除紀錄後會即時更新。新增前會檢查項目名稱與金額，並先顯示確認視窗。刪除前也會確認，確認後清單會播放動畫。

「收支統計」頁面用兩個分頁查看本月支出與收入分類；「個人設定」可以儲存姓名與每月預算，並查看預算使用進度。資料存到目前瀏覽器或裝置後，關閉再開啟仍可讀回。只有完全沒有存檔的第一次啟動才會建立測試資料；手動刪空清單後不會自動重新塞回測試資料。

## 初學者可以先看這幾段

1. 在 `main.dart` 搜尋 `class Expense`：一筆紀錄有哪些欄位，以及如何轉成 Map。
2. 搜尋 `_loadSavedData()`：了解 `async`、`await` 如何等待讀取本機資料。
3. 搜尋 `_addRecord()` 和 `_deleteRecord()`：了解如何更新 `ValueNotifier<List<Expense>>`。
4. 在 `shared_preferences_helper.dart` 看 `saveRecords()` 和 `readRecords()`：了解資料如何轉成 JSON 文字並保存。
5. 搜尋 `ValueListenableBuilder`：它會在清單改變時重新更新畫面。

> 注意：`shared_preferences` 適合這種小型練習資料，不是加密資料庫；資料保存在目前瀏覽器或裝置，不會自動同步到其他地方。
