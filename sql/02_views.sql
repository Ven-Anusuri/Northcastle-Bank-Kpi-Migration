-- Scoring, ranking and RAG views (SQLite)

CREATE VIEW vw_employee_monthly_score AS
        WITH role_weights AS (
            SELECT
                role,
                MAX(CASE WHEN metric_name = 'Lending' THEN weight_pct END) AS lending_weight,
                MAX(CASE WHEN metric_name = 'Investing' THEN weight_pct END) AS investing_weight,
                MAX(CASE WHEN metric_name = 'Banking units' THEN weight_pct END) AS banking_weight,
                MAX(CASE WHEN metric_name = 'LEI customer score' THEN weight_pct END) AS lei_weight
            FROM dim_role_weights
            GROUP BY role
        )
        SELECT
            fs.employee_id,
            fs.branch_id,
            de.branch_code,
            de.role,
            de.first_name,
            de.last_name,
            fs.month_number,
            fs.month_name,
            CASE
                WHEN de.role = 'Teller' THEN NULL
                ELSE fs.lending_actual / ft.target_lending
            END AS lending_pct_to_target,
            CASE
                WHEN de.role = 'Teller' THEN NULL
                ELSE fs.investing_actual / ft.target_investing
            END AS investing_pct_to_target,
            fs.banking_units_actual / ft.target_banking_units AS banking_units_pct_to_target,
            fs.lei_actual / ft.target_lei AS lei_pct_to_target,
            (
                COALESCE(CASE WHEN de.role = 'Teller' THEN NULL ELSE fs.lending_actual / ft.target_lending END, 0) * COALESCE(rw.lending_weight, 0)
                + COALESCE(CASE WHEN de.role = 'Teller' THEN NULL ELSE fs.investing_actual / ft.target_investing END, 0) * COALESCE(rw.investing_weight, 0)
                + COALESCE(fs.banking_units_actual / ft.target_banking_units, 0) * COALESCE(rw.banking_weight, 0)
                + COALESCE(fs.lei_actual / ft.target_lei, 0) * COALESCE(rw.lei_weight, 0)
            ) / 100.0 AS weighted_total_score
        FROM fact_sales fs
        JOIN fact_targets ft
            ON ft.employee_id = fs.employee_id
           AND ft.month_number = fs.month_number
        JOIN dim_employee de
            ON de.employee_id = fs.employee_id
        LEFT JOIN role_weights rw
            ON rw.role = de.role
        ORDER BY fs.employee_id, fs.month_number;

CREATE VIEW vw_employee_rank AS
        SELECT
            employee_id,
            branch_id,
            branch_code,
            role,
            first_name,
            last_name,
            month_number,
            month_name,
            lending_pct_to_target,
            investing_pct_to_target,
            banking_units_pct_to_target,
            lei_pct_to_target,
            weighted_total_score,
            RANK() OVER (
                PARTITION BY role, month_number
                ORDER BY weighted_total_score DESC
            ) AS rank_within_role,
            RANK() OVER (
                PARTITION BY branch_id, month_number
                ORDER BY weighted_total_score DESC
            ) AS rank_within_branch
        FROM vw_employee_monthly_score;

CREATE VIEW vw_branch_monthly_score AS
        WITH branch_sales AS (
            SELECT
                branch_id,
                month_number,
                SUM(lending_actual) AS lending_actual,
                SUM(investing_actual) AS investing_actual,
                SUM(banking_units_actual) AS banking_units_actual,
                SUM(lei_actual) AS lei_actual
            FROM fact_sales
            GROUP BY branch_id, month_number
        ),
        branch_targets AS (
            SELECT
                branch_id,
                month_number,
                SUM(target_lending) AS target_lending,
                SUM(target_investing) AS target_investing,
                SUM(target_banking_units) AS target_banking_units,
                SUM(target_lei) AS target_lei,
                SUM(target_compliance) AS target_compliance
            FROM fact_targets
            GROUP BY branch_id, month_number
        ),
        manager_weights AS (
            SELECT
                MAX(CASE WHEN metric_name = 'Lending' THEN weight_pct END) AS lending_weight,
                MAX(CASE WHEN metric_name = 'Investing' THEN weight_pct END) AS investing_weight,
                MAX(CASE WHEN metric_name = 'Banking units' THEN weight_pct END) AS banking_weight,
                MAX(CASE WHEN metric_name = 'LEI customer score' THEN weight_pct END) AS lei_weight,
                MAX(CASE WHEN metric_name = 'Compliance / Risk' THEN weight_pct END) AS compliance_weight
            FROM dim_role_weights
            WHERE role = 'Manager'
        )
        SELECT
            bs.branch_id,
            db.branch_code,
            db.branch_name,
            db.tier,
            bs.month_number,
            fc.month_name,
            bs.lending_actual / bt.target_lending AS lending_pct_to_target,
            bs.investing_actual / bt.target_investing AS investing_pct_to_target,
            bs.banking_units_actual / bt.target_banking_units AS banking_units_pct_to_target,
            bs.lei_actual / bt.target_lei AS lei_pct_to_target,
            fc.compliance_score / bt.target_compliance AS compliance_pct_to_target,
            (
                (bs.lending_actual / bt.target_lending) * mw.lending_weight
                + (bs.investing_actual / bt.target_investing) * mw.investing_weight
                + (bs.banking_units_actual / bt.target_banking_units) * mw.banking_weight
                + (bs.lei_actual / bt.target_lei) * mw.lei_weight
                + (fc.compliance_score / bt.target_compliance) * mw.compliance_weight
            ) / 100.0 AS weighted_total_score
        FROM branch_sales bs
        JOIN branch_targets bt
            ON bt.branch_id = bs.branch_id
           AND bt.month_number = bs.month_number
        JOIN dim_branch db
            ON db.branch_id = bs.branch_id
        JOIN fact_compliance fc
            ON fc.branch_id = bs.branch_id
           AND fc.month_number = bs.month_number
        CROSS JOIN manager_weights mw
        ORDER BY bs.branch_id, bs.month_number;

CREATE VIEW vw_branch_pacing AS
        SELECT
            branch_id,
            branch_code,
            branch_name,
            tier,
            month_number,
            month_name,
            lending_pct_to_target,
            investing_pct_to_target,
            banking_units_pct_to_target,
            lei_pct_to_target,
            compliance_pct_to_target,
            weighted_total_score,
            CASE
                WHEN weighted_total_score >= 1.0 THEN 'Green'
                WHEN weighted_total_score >= 0.9 THEN 'Amber'
                ELSE 'Red'
            END AS rag_status
        FROM vw_branch_monthly_score;

