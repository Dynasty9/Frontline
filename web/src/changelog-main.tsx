import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import "./index.css"
import ChangelogPage from "./changelog-page.tsx"

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ChangelogPage />
  </StrictMode>,
)
