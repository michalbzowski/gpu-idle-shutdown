# gpu-idle-shutdown

Ubuntu (20.04+/22.04/24.04): automatyczne wyłączenie komputera, gdy karta
NVIDIA nie wykonuje obliczeń przez **30 minut z rzędu** (konfigurowalne).
Zero obsługi po instalacji — sterowane systemd timerem, więc:

- działa co minutę,
- startuje samo po restarcie,
- wyłącza maszynę **bez hasła sudo** (skrypt działa jako root pod systemd-em).

## Jak jest podejmowana decyzja "GPU nie pracuje"

Sprawdzenie (co 60 s) uznaje kartę za **aktywną**, gdy:

- na GPU przypięty jest jakikolwiek proces obliczeniowy
  (`nvidia-smi --query-compute-apps`), LUB
- `utilization.gpu` którejkolwiek karty > progu `GPU_UTIL_MAX` (domyślnie 1%).

W pozostałych przypadkach zalicza jedno "idle". Po `IDLE_LIMIT` kolejnych idle
(30 = 30 minut) uruchamia `systemctl poweroff`. Stan nieznany (brak drivera,
błąd odczytu) — bezpiecznie: licznik restart do 0 i żadne wyłączenie.

## Instalacja (jednorazowo, wymaga sudo tylko raz)

```bash
git clone https://github.com/michalbzowski/gpu-idle-shutdown.git
cd gpu-idle-shutdown
sudo ./install.sh
```

Odinstalacja: `sudo ./install.sh uninstall`.

## Weryfikacja

```bash
systemctl status gpu-idle-check.timer            # timer działa?
systemctl list-timers --all | grep gpu-idle      # następny wyzwalacz
journalctl -u gpu-idle-check -f                  # logi na żywo (IDLE n/30 ...)
cat /var/lib/gpu-idle-shutdown/state             # bieżący licznik idle checków
```

## Bezpieczny test (NIE wyłączy maszyny)

```bash
sudo DRY_RUN=1 IDLE_LIMIT=1 /usr/local/bin/gpu-idle-shutdown.sh
# -> "DRY RUN: osiągnięte 1/1 minut idle — NIE wyłączam maszyny"
```

## Konfiguracja (zmienne środowiskowe w unit'ie service lub w skrypcie)

| Zmienna        | Domyślnie                  | Znaczenie                            |
|----------------|----------------------------------|--------------------------------------|
| `IDLE_LIMIT`   | 30                               | ile kolejnych minut idle => poweroff |
| `GPU_UTIL_MAX` | 1                                | próg utilization.gpu [%]              |
| `DRY_RUN`      | 0                                | 1 = test bez wyłączania               |

Trwały override przez systemd:

```bash
sudo systemctl edit gpu-idle-check.service
# [Service]
# Environment="IDLE_LIMIT=60"
sudo systemctl daemon-reload && sudo systemctl restart gpu-idle-check.timer
```

## Alternatywa: cron + sudoers (jeśli wolisz crona)

`crontab -e`:

```cron
* * * * * /usr/local/bin/gpu-idle-shutdown.sh >/dev/null 2>&1
```

`/etc/sudoers.d/gpu-idle` (użyj `sudo visudo -f <plik>` przy tworzeniu):

```
twoj_user ALL=(root) NOPASSWD: /usr/sbin/shutdown, /usr/sbin/poweroff
```

i w skrypcie zamiast `systemctl poweroff` → `sudo shutdown -h now`.
Wariant systemd z tego repo jest jednak czystszy — nie potrzebuje żadnego
NOPASSWD.

## Uwagi

- Plik stanu: `/var/lib/gpu-idle-shutdown/state` (liczba 0..IDLE_LIMIT).
- Logi trafiają do journal (`journalctl -u gpu-idle-check`); dodatkowy plik logu
  nie jest prowadzony — celowo ("bez obsługi").
- Multi-GPU: maszyna jest aktywna, gdy **ktokolwiek** z kart jest zajęta.
- Uwaga: sesja X/Wayland nie pojawia się w `--query-compute-apps`, a jej
  utilization często mieści się w 0-5% — komputer z desktopem może być uznany
  za "idle", nawet gdy ktoś go w tym czasie używa. Jeśli nie chcesz wyłączać
  maszyny podczas aktywnej sesji graficznej, dodaj do skryptu warunek
  zabezpieczający (np. sprawdzenie przez `loginctl`, czy nie ma sesji online).
