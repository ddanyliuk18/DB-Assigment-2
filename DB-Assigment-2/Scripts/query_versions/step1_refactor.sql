USE athlets01;

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

