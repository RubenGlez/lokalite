const verifyButton = document.querySelector("#verify");
const result = document.querySelector("#result");
const lifecycleButton = document.querySelector("#refresh-lifecycle");
const lifecycle = document.querySelector("#lifecycle");

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

lifecycleButton.addEventListener("click", async () => {
  lifecycleButton.disabled = true;

  try {
    const state = await window.__TAURI__.core.invoke("read_lifecycle_state");
    lifecycle.textContent = JSON.stringify(state, null, 2);
  } catch {
    lifecycle.textContent = "Lifecycle state unavailable.";
  } finally {
    lifecycleButton.disabled = false;
  }
});
