# Jak pracować w tym repo

Witaj w Lunar Lander! Ten plik jest dla nowej osoby w projekcie: jak uruchomić grę, jak wziąć ticket i doprowadzić go do zmergowanego PR-a, i jak zgłaszać to, co znajdziesz podczas testów. Szczegóły nie są tu powtarzane, tylko linkowane — źródłem prawdy są pliki wymienione niżej.

## Język

Ten plik jest po polsku, ale **kod, komentarze, commity, tytuły i opisy PR-ów, issue i dokumentacja są po angielsku**. Changelog jest generowany z tytułów PR-ów i czytają go gracze.

## Co przeczytać najpierw

1. [`README.md`](README.md) — czym jest gra, jej zasady, ograniczenia, konwencje kodu, pułapki („Gotchas”) i jak uruchamiać testy. To główny kontekst także dla agentów.
2. [`CLAUDE.md`](CLAUDE.md) — konwencje commitów, PR-ów i wydań (conventional commits, squash merge, release-please).
3. [`docs/agents/workflow.md`](docs/agents/workflow.md) — droga od ticketu do zmergowanego kodu.
4. [`docs/README.md`](docs/README.md) — indeks dokumentacji architektury i ADR-ów.
5. [`GLOSSARY.md`](GLOSSARY.md) — słownik pojęć gry (Office, Terminal, Transport offer, Border…). Używaj tych nazw w kodzie i w rozmowie z agentem.

## Przygotowanie

- **Godot 4.7.2** (wersja standardowa, nie „.NET/mono”) z [godotengine.org](https://godotengine.org/download/archive/4.7.2-stable/). Nie musi być w `PATH`: w poleceniach poniżej `Godot` oznacza ścieżkę do pliku wykonywalnego, na macOS np. `/Applications/Godot.app/Contents/MacOS/Godot`.
- **git** i **[GitHub CLI](https://cli.github.com/)** (`gh auth login`) — agent czyta przez `gh` issue i PR-y.
- **[Claude Code](https://claude.com/claude-code)** uruchomiony w katalogu repo. Plik `.claude/settings.json` z góry pozwala na bezpieczne polecenia (testy Godota, odczyt gita i `gh`), więc agent nie pyta o nie za każdym razem. Własne ustawienia trzymaj w `.claude/settings.local.json` (nie trafia do repo).
- Po sklonowaniu, raz: `Godot --headless --path . --import`.

## Granie i testowanie

- **Granie:** otwórz projekt w edytorze Godota i naciśnij F5.
- **Testy automatyczne:** `Godot --headless --path . --fixed-fps 60 -s tests/run_tests.gd` — kończy się kodem różnym od zera, gdy któryś test nie przejdzie. Te same testy uruchamia CI (`Tests`) na każdym PR-ze.
- **Zrzuty ekranu** wszystkich lokacji, w dzień i w nocy: `Godot --path . -s tools/capture.gd -- --out=<katalog>` (otwiera okno; przydatne przy review zmian wizualnych).
- Testy headless niczego nie renderują, więc wygląd i „czucie” lotu sprawdza tylko człowiek. Dlatego Twój playtest jest częścią każdego PR-a, który zmienia to, co widzi gracz.

## Od ticketu do PR-a

1. **Wybierz ticket** z etykietą [`ready-for-agent`](https://github.com/pkopczynski/lunar-lander/issues?q=is%3Aissue+is%3Aopen+label%3Aready-for-agent) — taki ticket agent może zrobić sam. Etykieta `ready-for-human` oznacza, że potrzebna jest decyzja albo playtest człowieka. Etykiety opisuje [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md). Przypisz ticket do siebie, żebyśmy nie robili tego samego.
2. **Zacznij od aktualnego `main`** i utwórz gałąź, np. `feat/123-shop-screen` albo `fix/130-pad-collision` (typ, numer ticketu, krótki opis).
3. **Daj agentowi ticket**, np. „Zaimplementuj #123 zgodnie z `docs/agents/workflow.md`”. Agent ma przeczytać ticket, jego spec i blokery, sprawdzić, czy spec nie jest nieaktualny („Stale specs”), i dopiero wtedy pisać kod. Jeśli ticket zakłada coś, co już nie jest prawdą, a zmienia to zakres, agent zatrzymuje się i komentuje na tickecie — wtedy decyzja należy do mnie.
4. **Sprawdź sam:** uruchom testy, zagraj w zmieniony fragment, przejrzyj diff. Odpowiadasz za PR, nie agent.
5. **Otwórz PR:**
   - Tytuł to conventional commit pisany dla gracza: `feat: …`, `fix: …`, `refactor: …` itd. (zasady w `CLAUDE.md`). Tytuł staje się jedynym commitem na `main` i linią w changelogu.
   - Opis zaczyna się od `Closes #<ticket>`, opisuje rozbieżności z ticketem i to, co powinien wiedzieć następny ticket.
   - PR aktualizuje dokumenty, których dotyczy zmiana (README, `docs/`, ADR) — patrz „Pull requests” w `docs/agents/workflow.md`.

## Review i merge

`main` jest chroniony:

- nie da się pushować bezpośrednio na `main` ani go nadpisać (`force-push`);
- każda zmiana wchodzi przez PR, mergowany przez **squash**;
- PR wymaga **mojej akceptacji** (1 approval); nowy push po akceptacji ją unieważnia;
- muszą przejść checki **`test`** (testy) i **`PR title`** (format tytułu), a wszystkie wątki review muszą być rozwiązane.

Gdy PR jest gotowy, oznacz mnie jako reviewera. Po akceptacji możesz go zmergować sam; gałąź usunie się automatycznie. PR-ów `chore(main): release x.y.z` (release-please) nie ruszaj — wydania robię ja.

## Zgłaszanie znalezisk z testów

Błąd albo coś, co wygląda lub „czuje się” źle w grze: [nowe issue](https://github.com/pkopczynski/lunar-lander/issues/new/choose) z szablonu **Bug / playtest finding** (wersja z prawego dolnego rogu Terminala, gdzie, kroki, czego się spodziewałeś, co się stało, najlepiej ze zrzutem ekranu). Dostaje etykietę `needs-triage`; ja decyduję, co dalej. Uwagi do konkretnego PR-a pisz w review tego PR-a.
