USE athlets01;


EXPLAIN
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
