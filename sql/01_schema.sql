-- Dominion Trust Branch Performance Scorecard - table schema (SQLite)

CREATE TABLE "dim_branch" ("branch_id" INTEGER, "branch_code" TEXT, "branch_name" TEXT, "tier" TEXT, "province" TEXT, "city" TEXT, "manager_count" INTEGER, "advisor_count" INTEGER, "teller_count" INTEGER, "employee_count" INTEGER, "opening_year" INTEGER);

CREATE TABLE "dim_employee" ("employee_id" INTEGER, "branch_id" INTEGER, "branch_code" TEXT, "tier" TEXT, "province" TEXT, "city" TEXT, "role" TEXT, "first_name" TEXT, "last_name" TEXT, "hire_date" TEXT);

CREATE TABLE "dim_role_weights" ("role" TEXT, "metric_name" TEXT, "weight_pct" REAL);

CREATE TABLE "fact_compliance" ("branch_id" INTEGER, "branch_code" TEXT, "month_number" INTEGER, "month_name" TEXT, "tier" TEXT, "province" TEXT, "city" TEXT, "compliance_score" REAL, "risk_score" REAL, "exceptions_count" INTEGER);

CREATE TABLE "fact_lei_survey" ("employee_id" INTEGER, "branch_id" INTEGER, "month_number" INTEGER, "month_name" TEXT, "survey_response_count" INTEGER, "lei_score" REAL);

CREATE TABLE "fact_sales" ("employee_id" INTEGER, "branch_id" INTEGER, "branch_code" TEXT, "role" TEXT, "tier" TEXT, "month_number" INTEGER, "month_name" TEXT, "lending_actual" REAL, "investing_actual" REAL, "banking_units_actual" REAL, "lei_actual" REAL);

CREATE TABLE "fact_targets" ("employee_id" INTEGER, "branch_id" INTEGER, "branch_code" TEXT, "role" TEXT, "tier" TEXT, "month_number" INTEGER, "month_name" TEXT, "target_lending" REAL, "target_investing" REAL, "target_banking_units" REAL, "target_lei" REAL, "target_compliance" REAL);

