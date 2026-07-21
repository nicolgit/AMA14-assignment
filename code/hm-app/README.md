# Hangar Mind App

Frontend single-page application (SPA) built with **Vue 3**, **TypeScript** and **Vite**.

## Prerequisites

- Node.js 20+ installed (`winget install -e --id OpenJS.NodeJS.LTS --source winget --accept-package-agreements --accept-source-agreements`)
- npm (bundled with Node.js)

Check your versions:

```powershell
node -v
npm -v
```

## Setup (first time or after pulling new dependencies)

```powershell
cd code/hm-app

# Install dependencies
npm config set registry https://packagefeedproxy.microsoft.io/npm/
npm install
```

## Run the dev server

```powershell
cd code/hm-app

# Start Vite with hot-reload
npm run dev

```

App available at: `http://localhost:5173`

The dev server provides Hot Module Replacement (HMR), so changes are reflected instantly in the browser.

## Build for production

```powershell
# Type-check + bundle into the dist/ folder
npm run build
```

The optimized, static output is written to `dist/`. These files can be served by any static web host (CDN, Azure Static Web Apps, etc.).

## Preview the production build

```powershell
# Serve the contents of dist/ locally
npm run preview
```

This starts a local static server so you can verify the production bundle before deploying.

## Run/debug in VS Code

1. Open the `hm-app` folder in VS Code
2. Install the **Vue - Official** extension (Volar) for `.vue` SFC support
3. Start the dev server with `npm run dev`
4. For breakpoint debugging in the browser, install the **JavaScript Debugger** (built-in) and create this launch config (`.vscode/launch.json`):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug SPA (Chrome)",
      "type": "chrome",
      "request": "launch",
      "url": "http://localhost:5173",
      "webRoot": "${workspaceFolder}/src"
    }
  ]
}
```

5. Run `npm run dev` first, then press `F5` to attach the browser debugger.

## Project structure

```
hm-app/
├── index.html             ← SPA entry point
├── package.json
├── vite.config.ts         ← Vite + Vue plugin config
├── tsconfig*.json         ← TypeScript configuration
├── public/                ← static assets served as-is
└── src/
    ├── main.ts            ← app bootstrap
    ├── App.vue            ← root component
    ├── style.css          ← global styles
    ├── assets/            ← imported assets (bundled)
    └── components/        ← reusable Vue components
```

## Useful commands

| Action | Command |
|--------|---------|
| Install dependencies | `npm install` |
| Start dev server (HMR) | `npm run dev` |
| Build for production | `npm run build` |
| Preview production build | `npm run preview` |
| Add a package | `npm install <pkg>` |
| Add a dev-only package | `npm install -D <pkg>` |
