# DB-Assigment-2
## ⚙️ Query Optimization Steps

### Original Query

```sql
SELECT DISTINCT 
    a.season,
    a.discipline,
    a.sex,
    a.nationality,
    AVG(a.mark_numeric) AS avg_mark,
    (
        SELECT MAX(b.result_score)
        FROM all_disciplines_combined b
        WHERE b.discipline = a.discipline
          AND b.season = a.season
          AND b.sex = a.sex
    ) AS max_score
FROM all_disciplines_combined a
WHERE a.age_at_event > (
    SELECT AVG(age_at_event)
    FROM all_disciplines_combined
)
  AND a.mark_numeric IS NOT NULL
GROUP BY a.season, a.discipline, a.sex, a.nationality;
```

**Проблеми**:

* Підзапит у `SELECT` виконується для кожного рядка повільно.
* Використання `DISTINCT` зайве, бо вже є `GROUP BY`.
* Відсутність оптимізації через попередню агрегацію.

---

### Step 1: Refactoring with CTE

```sql
WITH max_scores AS (
    SELECT
        a.season,
        a.discipline,
        a.sex,
        MAX(a.result_score) AS max_score
    FROM all_disciplines_combined a
    GROUP BY a.season, a.discipline, a.sex
)

SELECT   
    b.season,
    b.discipline,
    b.sex,
    b.nationality,
    AVG(b.mark_numeric) AS avg_mark,
    ms.max_score
FROM all_disciplines_combined b
JOIN max_scores ms
    ON b.discipline = ms.discipline
    AND b.season = ms.season
    AND b.sex = ms.sex
WHERE b.age_at_event > (
    SELECT AVG(age_at_event)
    FROM all_disciplines_combined
)
  AND b.mark_numeric IS NOT NULL
GROUP BY b.season, b.discipline, b.sex, b.nationality, ms.max_score;
```

*Заміна корельованого підзапиту на CTE (`WITH`) + JOIN зменшує кількість підзапитів.

*Менше повторних обчислень, простіший `Execution Plan`.

---

### Step 2: Adding Indexes

```sql
CREATE INDEX join_IDX ON all_disciplines_combined(season, discipline, sex);
CREATE INDEX age_IDX ON all_disciplines_combined(age_at_event);
```

*Індекси дозволяють прискорити операції JOIN і WHERE, зменшуючи кількість рядків, які сканує сервер.

*Запит стає відчутно швидшим, особливо на великих об'ємах даних.

---

### Step 3: Forcing Index Usage

```sql
WITH max_scores AS (
    SELECT
        a.season,
        a.discipline,
        a.sex,
        MAX(a.result_score) AS max_score
    FROM all_disciplines_combined a
    GROUP BY a.season, a.discipline, a.sex
)

SELECT   
    b.season,
    b.discipline,
    b.sex,
    b.nationality,
    AVG(b.mark_numeric) AS avg_mark,
    ms.max_score
FROM all_disciplines_combined b
FORCE INDEX (join_IDX, age_IDX)
JOIN max_scores ms
    ON b.discipline = ms.discipline
    AND b.season = ms.season
    AND b.sex = ms.sex
WHERE b.age_at_event > (
    SELECT AVG(age_at_event)
    FROM all_disciplines_combined USE INDEX (age_IDX)
)
  AND b.mark_numeric IS NOT NULL
GROUP BY b.season, b.discipline, b.sex, b.nationality, ms.max_score;
```

*Явне вказування MySQL, що потрібно використовувати певні індекси (`FORCE INDEX`) — допомагає уникнути неправильного плану запиту.

*Покращення стабільності та передбачуваності продуктивності.

---

## Performance Comparison

| Виміри                  | Без індексів           | З індексами + FORCE INDEX   |
| ----------------------- | ---------------------- | --------------------------- |
| Загальний час виконання | \~13.5 с               | \~10.6 с                    |
| Nested Loop Join        | \~10.1 с               | \~9.8 с                     |
| Materialize CTE         | \~4.2 с                | \~6.4 с                     |
| AVG(age\_at\_event)     | \~0.75 с               | \~0.82 с                    |
| Тип сканування          | Index scan (частковий) | Index scan + Covering index |

**Деталі**:

* З індексами спостерігається пришвидшення приблизно **на 2.9 секунди (\~21%)**.
* Покращення відбулося завдяки **індексу на колонках JOIN (`season, discipline, sex`)** та **індексу для фільтрації (`age_at_event`)**.
* `FORCE INDEX` дозволяє контролювати вибір плану виконання, уникаючи повного сканування таблиці.

---

## Висновки

* **Індекси значно покращують** продуктивність запитів, особливо при великих таблицях.
* **CTE + JOIN** — краща альтернатива підзапитам.
* **FORCE INDEX** варто використовувати тоді, коли MySQL не обирає потрібні індекси автоматично.
* Загальний виграш продуктивності — **20–25%** при використанні оптимального індексування.
