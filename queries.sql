--Add a new row in patients--
INSERT INTO "patients" ( "first_name", "last_name", "age", "gender", "country")
VALUES
   ( 'Eylaf', 'Mahdi', 22, 'F', 'Sudan'),
   ('Adam', 'John', 45, 'M', 'Malaysia');

--Add a new row in claims--
INSERT INTO "claims" ("patient_id","insurer_id", "hospital_id",
"submitted", "responded", "overall_status", "total")
VALUES
(123, 34, 2, '2024-08-01', '2024-08-15', 'approved', 1433.23);

--Add a new row in medicalServices--
 INSERT INTO "medicalServices" ( "claim_id", "service_type", "price")
 VALUES ( 10, 'blood pressure test', 1234);

--Updating all services to finished at once for a specific claim--
UPDATE "serviceStatus" SET "status" = 'finished'
WHERE "medicalService_id" = 533;

--Delete rows starts with Ey--
DELETE FROM "patients" WHERE "first_name" LIKE ('Ey%');


--Find patients who have more than 2 times rejected--
SELECT "patients"."id", "first_name", "last_name", COUNT(*) as num_rejected FROM "patients" JOIN "claims" ON
"patients"."id" = "claims"."patient_id"
WHERE "overall_status" = 'rejected'
GROUP BY "claims"."patient_id"
HAVING COUNT(*)  > 2;


--View to save out of pocket amount for patients--
 CREATE VIEW "out_of_pocket" as
 SELECT t1."patient_id", t1.sum_total, t2.total_covered, t1.sum_total - t2.total_covered AS "out_of_pocket"
  FROM
  (SELECT "patient_id", SUM("total") AS sum_total FROM "claims" GROUP BY "patient_id") AS t1
 JOIN
  (SELECT "patient_id", SUM("covered_amount") AS total_covered
  FROM "claims" JOIN "payments" ON
  "claims"."id" = "payments"."claim_id" GROUP BY "patient_id" ) AS t2
  ON t1."patient_id" = t2."patient_id";

--Find top 5 patients in the list who paid highest out-of-pucket overall--
SELECT "patient_id", "out_of_pocket"."out_of_pocket" AS top5 FROM "out_of_pocket"
  ORDER BY "out_of_pocket"."out_of_pocket" DESC
  LIMIT 5;


--Find the insurer who contributed the most--
SELECT "insurer_company", SUM("covered_amount") AS total_covered FROM "insurers" JOIN "claims"
ON "insurers"."id" = "claims"."insurer_id"
JOIN "payments" ON "payments"."claim_id" = "claims"."id"
GROUP BY "insurer_company"
ORDER BY total_covered DESC
LIMIT 1;


--Find total revenue per month--
SELECT SUM("out_of_pocket"."out_of_pocket" + total_covered) AS total_revenue,
 STRFTIME('%m', "submitted") AS the_month FROM "out_of_pocket"
JOIN "claims" ON "claims"."patient_id" = "out_of_pocket"."patient_id"
GROUP BY STRFTIME('%m', "submitted");


--Find all the rejected services--
SELECT med."id", "service_type", "reason" FROM "medicalServices" med JOIN
"serviceStatus" sta ON
med."id" = sta."medicalService_id"
WHERE "status" = 'rejected';


--Find the top 3 rejection reasons for each service type per insurer --
WITH rejections_count as (
  SELECT "insurers"."id", "insurer_company", "claims"."id" as claimID,
  "medicalServices"."id", "service_type", "reason"
  FROM "insurers"
  JOIN "claims" ON "insurers"."id" = "claims"."insurer_id"
  JOIN "medicalServices" ON "medicalServices"."claim_id" = "claims"."id"
  JOIN "serviceStatus" sta ON
  "medicalServices"."id" = sta."medicalService_id"
 WHERE "status" = 'rejected'),
top3 AS(
SELECT "insurer_company", "service_type", "reason", COUNT(*) AS totalrea,
 RANK() OVER(PARTITION BY "insurer_company", "service_type" ORDER BY COUNT(*) DESC) AS rn
 FROM rejections_count
GROUP BY "insurer_company", "service_type", "reason"
)
SELECT * FROM top3 WHERE "insurer_company" = 'XYZ Asurance' AND rn <= 3
ORDER BY "service_type", totalrea DESC;

--Find service types have the highest rejection rates--
WITH ranked_services AS (
  SELECT "service_type", COUNT(*) AS total_rej,
 RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk
  FROM "medicalServices" med JOIN "serviceStatus" sta
      ON med."id" = sta."medicalService_id"
      WHERE "status" = 'rejected'
        GROUP BY "service_type")
  SELECT * FROM ranked_services WHERE
  rnk <= 3
  ORDER BY total_rej DESC;

--Compare if delays are longer for partialy covered cliams vs totally covered cliams--
WITH delay_partiallyCovered AS (
SELECT ROUND(SUM("price"), 2) AS total_covered, "claim_id", "total" AS total_claim,
     AVG(julianday("responded") - julianday("submitted")) AS "delay"
     FROM "medicalServices" JOIN "claims" ON "medicalServices"."claim_id" = "claims".id
GROUP BY "claim_id"
HAVING  ROUND(SUM("price"), 2) != "total"
),
delay_totalCovered as (
  SELECT ROUND(SUM("price"), 2) AS total_covered, "claim_id", "total" AS total_claim,
   AVG(julianday("responded") - julianday("submitted")) AS "delay"
   FROM "medicalServices" JOIN "claims" ON "medicalServices"."claim_id" = "claims"."id"
GROUP BY "claim_id"
HAVING  ROUND(SUM("price"), 2) = "total"
)
SELECT
  ROUND((SELECT AVG("delay") FROM delay_partiallyCovered), 2) AS avg_partially,
  ROUND((SELECT AVG("delay") FROM delay_totalCovered), 2) AS avg_totally;

--Find the average response time per insurer
 SELECT "insurer_company",
 CAST(AVG(julianday("responded") - julianday("submitted")) AS INT) AS avg_response_time
 FROM "claims" JOIN "insurers" ON "claims"."insurer_id" = "insurers"."id"
 WHERE "responded" IS NOT NULL
 GROUP BY "insurer_company";

--Find patients who have more than 3 claims--
SELECT "patient_id", COUNT(*)  FROM "claims"
GROUP BY "patient_id"
HAVING COUNT(*) > 3;

--View for partially covered claims--
CREATE VIEW partially_covered AS
SELECT ROUND(SUM("price"), 2) AS total_covered, "claim_id", "total" AS total_claim
FROM "medicalServices" JOIN "claims"
   ON "medicalServices"."claim_id" = "claims".id
GROUP BY "claim_id"
HAVING  ROUND(SUM("price"), 2) != "total";


--Find how many claims were fully approved, partially approved, or fully rejected year 2024--
SELECT "overall_status", COUNT(*) FROM "claims"
WHERE STRFTIME('%Y', "responded") = '2024'
GROUP BY "overall_status";


--Trigger to add new services auto to the serviceStatus table with pending status--
CREATE TRIGGER new_service_trigger
AFTER INSERT ON "medicalServices"
FOR EACH ROW
BEGIN
INSERT INTO "serviceStatus" ( "medicalService_id", "status", "reason")
VALUES ( new.id, 'pending', NULL);
END;

--View for accessing only the claim, serviceType and its status--
CREATE VIEW per_service AS
SELECT "claim_id", "service_type", "status" FROM
"medicalServices" JOIN "serviceStatus" ON
"medicalServices"."id" = "serviceStatus"."medicalService_id";

--Find the claims that all services are finished--
SELECT COUNT("status") AS all_finished, "claim_id" FROM "serviceStatus" JOIN
    "medicalServices" on "serviceStatus"."medicalService_id" = "medicalServices"."id"
   GROUP BY "claim_id"
   HAVING SUM("status" = 'finished') = COUNT(*);

--Update the overall_status auto to approved when a claim has finished all services--
CREATE TRIGGER accepted
AFTER INSERT ON "serviceStatus"
FOR EACH ROW
BEGIN
UPDATE "claims" SET "overall_status" = 'approved'
WHERE "id" in (
     SELECT "claim_id"
        FROM "medicalServices"
        WHERE "id" = NEW."medicalService_id"
) and id in(
  SELECT "claim_id" FROM "serviceStatus" JOIN
    "medicalServices" on "serviceStatus"."medicalService_id" = "medicalServices"."id"
    WHERE "claim_id" in (
     SELECT "claim_id"
        FROM "medicalServices"
        WHERE "id" = NEW."medicalService_id"
)
   GROUP BY "claim_id"
   HAVING SUM("status" = 'finished') = COUNT(*)
);
END;


--Trigger to delete all rows from serviceStatus when a new approved of a claim is added to the claims table--
CREATE TRIGGER "DELETEService_whenApproved"
AFTER UPDATE ON "claims"
FOR EACH ROW
BEGIN
  DELETE FROM "serviceStatus" WHERE
  "medicalService_id" IN (
    SELECT "id" FROM "medicalServices" WHERE
    "claim_id" = NEW."id"
  ) AND NEW."overall_status" = 'approved';
END;


--Find patient Counts by Gender and Country--
SELECT COUNT("gender"),
CASE
WHEN gender = 'F' THEN 'females'
ELSE 'males'
END
AS byGender,
 "country" FROM "patients"
GROUP BY "country", "gender";



--Find most frequent (top) gender–country combination--
SELECT COUNT("patients"."id") AS numPatient, "gender", "country"
FROM "patients" JOIN "claims"
ON "patients"."id" = "claims"."patient_id"
GROUP BY  "country", "gender"
ORDER BY numPatient DESC
LIMIT 1;


--Find hospitals by claims volume--
SELECT "hospital_name", COUNT("claims"."hospital_id") AS numClaims
FROM "hospitals" LEFT JOIN "claims"
ON "hospitals"."id" = "claims"."hospital_id"
GROUP BY  "hospital_name"
ORDER BY numClaims DESC;

--Find patients whose claims exceed their monthly premiums--
WITH amount_permium AS
(SELECT "patient_id", "amount", "frequency"
FROM "permiums"
WHERE "frequency" = 'monthly'
),
totalClaims AS(
SELECT "patient_id", SUM("total") as sumClaims FROM "claims"
WHERE STRFTIME('%m', "submitted") = '09'
GROUP BY "patient_id")
SELECT amount_permium."patient_id", "amount", "frequency", sumClaims,
 ROUND(1.0 * sumClaims / "amount", 2) AS loss_ratio
FROM amount_permium JOIN totalClaims ON
amount_permium."patient_id" = totalClaims."patient_id"
WHERE sumClaims > "amount";

--Find insurers who improved their rejection rate over augest and september--
WITH monthly AS (
  SELECT
    "insurer_id",
    STRFTIME('%m', "submitted") AS "month",
    SUM(julianday("responded") - julianday("submitted")) AS totalDays
  FROM "claims"
  WHERE strftime('%m', "submitted") IN ('08', '09')
  GROUP BY "insurer_id", "month"
)
SELECT "insurer_id",
  SUM(CASE WHEN "month" = '08' THEN totalDays ELSE 0 END) AS augDays,
  SUM(CASE WHEN "month" = '09' THEN totalDays ELSE 0 END) AS sepDays,
  CASE
    WHEN SUM(CASE WHEN "month" = '09' THEN totalDays ELSE 0 END)
         < SUM(CASE WHEN "month" = '08' THEN totalDays ELSE 0 END)
    THEN 'Improved'
    ELSE 'Not Improved'
  END AS "Status"
FROM monthly
GROUP BY "insurer_id";


--Find services that are most costly in a desc order--
WITH costly_services AS (
SELECT "service_type",
ROUND(AVG("price"), 2) AS avg_price
FROM "medicalServices"
GROUP BY "service_type")
SELECT "service_type", avg_price, RANK() OVER ( ORDER BY avg_price DESC) AS rnk
   FROM costly_services
  ORDER BY avg_price DESC;


--find fastest and slowest hospitals--
WITH efficient_hospitals AS (
SELECT "hospital_name", AVG(julianday("responded") - julianday("submitted")) AS avg_days
FROM "hospitals" JOIN "claims"
ON "hospitals"."id" = "claims"."hospital_id"
WHERE "responded" IS NOT NULL
GROUP BY "hospital_name")
   SELECT "hospital_name", avg_days
   FROM efficient_hospitals
   WHERE avg_days = (SELECT MIN(avg_days) FROM efficient_hospitals) OR
   avg_days = (SELECT MAX(avg_days) FROM efficient_hospitals);


--Patient report--
CREATE VIEW patient_claims_summary AS
SELECT "claims"."patient_id", "first_name",
COUNT("payments"."claim_id") AS total_claims,
SUM("total") AS total_claim_amount,
SUM("covered_amount") AS total_paid,
SUM ("out_of_pocket"."out_of_pocket") AS outstanding_balance,
ROUND(100.0 * SUM(CASE WHEN "overall_status" = 'approved' THEN 1 ELSE 0 END) / COUNT("claim_id"), 2)
 AS approval_rate
 FROM
 "claims" JOIN "patients" ON "claims"."patient_id" = "patients"."id"
 LEFT JOIN "payments" ON "claims"."id" = "payments"."claim_id"
 LEFT JOIN "out_of_pocket" ON "claims"."patient_id" = "out_of_pocket"."patient_id"
 GROUP BY "patient_id";

CREATE INDEX patientID ON "patients"("id");
CREATE INDEX permium_patientID ON "permiums"("patient_id");
CREATE INDEX insurerID ON "claims"("insurer_id");
CREATE INDEX claim_patientID ON "claims"("patient_id");
CREATE INDEX claimsID ON "claims"("id");
CREATE INDEX claim_hospitalID ON "claims"("hospital_id");
CREATE INDEX hospitalID ON "hospitals"("id");
CREATE INDEX claims_total ON "claims"("total");
CREATE INDEX date_submitted ON "claims"("submitted");
CREATE INDEX  date_responded ON "claims"("responded");
CREATE INDEX generalStatus ON "claims"("overall_status");
CREATE INDEX claim_medicalID ON "medicalServices"("claim_id");
CREATE INDEX Service_medicalID ON "serviceStatus"("medicalService_id");
CREATE INDEX index_service_status ON "serviceStatus"("status");
CREATE INDEX payment_claimID ON "payments"("claim_id");
CREATE INDEX paymentCoverd ON "payments"("covered_amount");
