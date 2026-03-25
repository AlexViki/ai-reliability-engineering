## 1. UI Access Endpoints

| UI Component | Port-forward Command | Access URL |
|--------------|----------------------|------------|
| **Flux UI (Capacitor)** | `kubectl port-forward svc/capacitor -n flux-system 9000:9000` | [http://localhost:9000](http://localhost:9000) |

> [!NOTE]
> The "Next" version of Capacitor was evaluated but requires a private beta license, so the **stable version** (v0.4.8) was chosen for this lab setup.