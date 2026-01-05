<p align="center">
  <img src="../../logo.png" alt="VISOR logo" height="180" />
</p>

<h1 align="center">VISOR — Vulnerability Identification Scanner & Operational Reporter</h1>

Быстрый сканер безопасности для Infrastructure-as-Code и конфигурационных файлов.

Главная особенность VISOR — полная свобода действий. Это не жестко заданный набор проверок. Вы можете писать и добавлять собственные правила для любых текстовых форматов, специфичных конфигов или внутренних стандартов компании.

## Возможности
- **Гибкие правила:** Обычный YAML. Вы сами определяете, что искать.
- **Детекторы контекста:** Сканер понимает разницу между Dockerfile и конфигом NGINX по путям или содержимому.
- **Двуязычность:** Описания правил на русском и английском.
- **Оценка рисков:** Подсчет общего балла (Score), CVSS, CWE и вывод уровня критичности.
- **Управление исключениями:** Поддержка игнорирования проверок через комментарии в коде.

## Требования
- Python 3.9+
- Пакеты: `typer`, `rich`, `pyyaml`, `identify`

Установка:

```bash
pip install -r requirements.txt
# или:
pip install typer rich pyyaml identify
```

## Использование (CLI)

Основной интерфейс — командная строка. Поддерживается сканирование файлов, папок и гибкая фильтрация вывода.

```text
Usage: main.py [OPTIONS] PATHS...

╭─ Arguments ──────────────────────────────────────────────────────────────────────────────────╮
│ * paths      PATHS...  Paths to scan [required]                                              │
╰──────────────────────────────────────────────────────────────────────────────────────────────╯
╭─ Options ────────────────────────────────────────────────────────────────────────────────────╮
│ --rules           -r      PATH      [default: rules]                                         │
│ --rule-file       -f      PATH                                                               │
│ --lang            -l      TEXT      [default: ru]                                            │
│ --output          -o      PATH                                                               │
│ --threads         -t      INTEGER   [default: 4]                                             │
│ --sort-by         -s      TEXT      severity|file [default: severity]                        │
│ --hide-low-info   -m                Скрыть LOW и INFO из вывода                              │
│ --min-severity            TEXT      Минимальный уровень для показа:                          │
│                                     CRITICAL|HIGH|MEDIUM|LOW|INFO [default: INFO]            │
│ --help                              Show this message and exit.                              │
╰──────────────────────────────────────────────────────────────────────────────────────────────╯

```

## Примеры запуска

Сканирование папки (вывод на английском, группировка по файлам):

```bash
python main.py examples/ -s file -l en

```

Запуск с конкретным файлом правил:

```bash
python main.py examples/ -f rules/dockerfile.yaml

```

Генерация отчета в JSON (для CI/CD) и скрытие неважных уведомлений:

```bash
python main.py examples/ -l en -o visor.json --hide-low-info

```

## Как работают правила

Система построена на YAML-паках. Вы можете создать правило для любого типа файлов.

Пример структуры правила:

```yaml
metadata:
  severity_map:
    CRITICAL: {color: "red", deduction: 40}
    HIGH: {color: "light_red", deduction: 25}
    MEDIUM: {color: "yellow", deduction: 15}
    LOW: {color: "blue", deduction: 5}
    INFO: {color: "white", deduction: 0}

target_tag: my-custom-conf  # Тег для привязки правил к файлам (корневой уровень)

detect:                       # Условия активации правил
  path_glob_any:
    - "**/*.conf"
  yaml:                       # (Опционально) проверка структуры YAML
    required_root_keys_any: ["settings"]

rules:
  - id: "SEC-001"
    type: "regex"             # regex | contains | not_contains
    pattern: "debug = true"
    severity: "CRITICAL"
    cvss: 7.5
    cwe: [200]
    description:
      ru: "Режим отладки включен в продакшене"
      en: "Debug mode is enabled"

```

Примечания:
- `severity_map` — необязателен; `color` влияет на оформление вывода. Поле `deduction` сохраняется в результатах для кастомных интеграций, но на встроенный расчёт Score не влияет.
- `cvss` должен быть указан для точного расчёта. Если не указать, движок подставит значения по умолчанию по уровню: `CRITICAL=9.0`, `HIGH=7.5`, `MEDIUM=5.0`, `LOW=3.0`, `INFO=0.0`.

### Типы проверок

1. **regex**: Поиск по регулярному выражению (Python re).
2. **contains**: Поиск точного совпадения подстроки.
3. **not_contains**: Срабатывает, если обязательная строка отсутствует.

### Обязательные поля правил

Для корректной работы сканера каждое правило ДОЛЖНО содержать:
- `id`
- `type` (regex|contains|not_contains)
- `pattern`
- `severity`
- `cvss` (обязательно)
- `cwe` (обязательно)
- `description` с ключами `ru` и `en`

> Рекомендуется всегда явно задавать `cvss` в каждом правиле. Это влияет на Score.

## Исключения (Suppressions)

Вы можете отключать проверки прямо в проверяемых файлах, используя комментарии.

Игнорировать весь файл:

```text
# scan-ignore-file
# scan-ignore-file: RULE_ID_1, RULE_ID_2

```

Игнорировать конкретную строку:

```text
# scan-ignore
# scan-ignore: RULE_ID_1

```

## Интеграция с CI (GitHub Actions)

Пример использования в пайплайне. Билд упадет, если оценка безопасности (Score) ниже 80.

```yaml
name: visor-scan
on: [push, pull_request]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
        with: { python-version: '3.11' }
      - name: Install jq
        run: sudo apt-get update && sudo apt-get install -y jq
      - run: pip install -r requirements.txt
      - run: python main.py . -l en -o visor.json
      - name: Gate Check
        run: |
          SCORE=$(jq -r '.score' visor.json)
          echo "Security Score: $SCORE"
          if [ "$SCORE" -lt 80 ]; then exit 1; fi

```

## Расчёт Score

- Для каждого файла берётся максимальный CVSS из его находок.
- Считается среднее этих максимумов по всем файлам: `avg_max_cvss`.
- Итоговый балл: `Score = max(0, 100 - round(avg_max_cvss * 10))`.

Примеры:
- Нет находок → `avg_max_cvss = 0.0` → `Score = 100`.
- `avg_max_cvss = 5.0` → `Score = 50`.
- `avg_max_cvss = 9.8` → `Score = 2`.

Замечание: `Score` не зависит от `deduction` и не равен сумме CVSS. Он отражает «средний максимум» риска по файлам.

## Roadmap
- [ ] Экспорт отчетов в формат SARIF для интеграции с GitHub Security Tab.
- [ ] Нативная поддержка сканирования переменных окружения (ENV).
- [ ] Расширение стандартных паков правил для Terraform и NGINX.
- [ ] Поддержка многострочных регулярных выражений для сложных проверок.
- [ ] Веб-интерфейс для просмотра и управления правилами.

## Лицензия
Распространяется под лицензией MIT. Используйте, копируйте и модифицируйте как хотите.

