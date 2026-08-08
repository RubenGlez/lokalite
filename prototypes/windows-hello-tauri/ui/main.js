const verifyButton = document.querySelector("#verify");
const result = document.querySelector("#result");

verifyButton.addEventListener("click", async () => {
  verifyButton.disabled = true;
  result.textContent = "Waiting for Windows Hello…";

  try {
    const outcome = await window.__TAURI__.core.invoke("verify_with_windows_hello");
    result.textContent = JSON.stringify(outcome, null, 2);
  } catch {
    // The backend is designed to return typed failures. This is only a final
    // presentation-layer guard and intentionally exposes no raw error details.
    result.textContent = JSON.stringify({
      status: "failed",
      sessionStarted: false,
      fallbackOffered: false,
    }, null, 2);
  } finally {
    verifyButton.disabled = false;
  }
});
