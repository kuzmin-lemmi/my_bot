# APK install and Telegram check

## 1) One-time GitHub setup

In your GitHub repo, open `Settings -> Secrets and variables -> Actions` and add 2 repository secrets:

- `BACKEND_URL` = your backend URL reachable from the phone, for example `http://192.168.1.42:8000`
- `MVP_TOKEN` = same value as `MVP_TOKEN` in `backend/.env`

## 2) Build APK on GitHub

1. Open `Actions` tab in GitHub.
2. Choose workflow `Build Android APK`.
3. Click `Run workflow`.
4. Wait until the run is green.

## 3) Download and install on phone

1. Open the completed workflow run.
2. In `Artifacts`, download `focusday-app-release`.
3. Unzip it; inside is `app-release.apk`.
4. Send `app-release.apk` to your phone (Telegram Saved Messages, Drive, USB, etc.).
5. On phone, open APK and install.

If Android blocks install, enable `Install unknown apps` for your browser/files app.

## 4) Run backend + Telegram bot on PC

Open terminal 1:

```bash
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Open terminal 2:

```bash
cd backend
python -m bot.main
```

## 5) End-to-end test (phone + Telegram + backend)

1. In Telegram, send to your bot: `Купить воду`.
2. In mobile app, pull-to-refresh on `Сегодня` screen.
3. Goal should appear in app.
4. Tap `Готово` in app.
5. Refresh again and verify status changed.

## 6) If something does not work

- Ensure phone and PC are on same Wi-Fi.
- Ensure `BACKEND_URL` uses PC LAN IP, not `localhost`.
- Check `http://<PC_IP>:8000/health` in phone browser.
- Verify the same `MVP_TOKEN` is used in backend and APK build secret.
