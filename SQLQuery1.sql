
--This dataset is AI-generatedo to protect commercial sensitivity and personal privacy.
--While the data values are simulated, the business context, data structure, analytical logic, 
--and workflows are based on a real company project that i have done
--------CLIENTS--------
USE Futurewell;
GO
--Total Clients
Select Count(*) As total_clients
From dbo.Clients$

--Number of clients by gender
Select gender,Count(*) as clients
From dbo.Clients$
Group by gender

--Age Distribution

Select AVG(age) AS avg_age,
       Max(age) AS max_age,
	   Min(age) As min_age
From dbo.Clients$

-- Monthly client sign ups
SELECT
  DATETRUNC(month, join_date) AS month,
  COUNT(*) AS new_clients
FROM dbo.Clients$
GROUP BY DATETRUNC(month, join_date)
ORDER BY month;

-- Average engagement metrics per client
SELECT client_id,
       AVG(messages_sent)     AS avg_messages,
       AVG(journal_entries)   AS avg_journals,
       AVG(metrics_logged)    AS avg_metrics
FROM Engagement$
GROUP BY client_id;






--because this a a healthcare company so focus on appointment and revenue( for others it can be orders,services,etc)
--------Appointment volume and Revenue--------

-- Total number of appointments and cancelled vs attended
Select status,count(*) AS count
From Appointments$
Group by status


-- Revenue generated each month
SELECT
  DATETRUNC(month, appointment_date) AS month,
  SUM(revenue) AS monthly_revenue
FROM Appointments$
WHERE status = 'Attended'
GROUP BY DATETRUNC(month, appointment_date)
ORDER BY month;


-- Top providers by total revenue
SELECT TOP 5
  p.provider_name,
  SUM(a.revenue) AS total_revenue
FROM Appointments$ a
JOIN Providers$ p ON a.provider_id = p.provider_id
WHERE a.status = 'Attended'
GROUP BY p.provider_name
ORDER BY total_revenue DESC;

-- Monthly revenue from attended appointments
WITH monthly_revenue AS (
    SELECT
        DATETRUNC(month, appointment_date) AS month,
        SUM(revenue) AS revenue
    FROM Appointments$
    WHERE status = 'Attended'
    GROUP BY DATETRUNC(month, appointment_date)
),
monthly_costs AS (
    SELECT
        month,              -- already monthly,  NOT DATETRUNC again
        SUM(amount) AS cost
    FROM Costs$
    GROUP BY month
)
SELECT
    r.month,
    r.revenue,
    c.cost,
    r.revenue - ISNULL(c.cost, 0) AS profit
FROM monthly_revenue r
LEFT JOIN monthly_costs c
    ON r.month = c.month
ORDER BY r.month;


--------Marketing Performance--------
-- Compute conversion rate and cost per conversion by channel
SELECT channel,
       SUM(leads_count)        AS total_leads,
       SUM(conversions)        AS total_conversions,
       SUM(cost)               AS total_cost,
       SUM(conversions) / NULLIF(SUM(leads_count), 0) AS conversion_rate,
       SUM(cost) / NULLIF(SUM(conversions), 0)       AS cost_per_conversion
FROM MarketingLeads$
GROUP BY channel
ORDER BY conversion_rate DESC;

--------Health Metrics--------
--Average health metrics--
Select AVG(weight_kg) AS avg_weight,
       AVG(bmi) AS avg_bmi,
	   AVG(bp_systolic) AS avg_systolicBP,
	   AVG(bp_diastolic) AS avg_diastolicBP,
	   AVG(cholesterol_mg_dl) AS avg_cholesterol
From HealthMetrics$

--Find clients with any problem 
Select client_id, 
       AVG(bmi) AS avg_bmi,
	   AVG(bp_systolic) AS avg_systolicBP,
	   AVG(bp_diastolic) AS avg_diastolicBP,
	   AVG(cholesterol_mg_dl) AS avg_cholesterol
From HealthMetrics$
Group by client_id
Having AVG(bmi)>30 OR AVG(bp_systolic) >130 OR  AVG(bp_diastolic)>80 OR AVG(cholesterol_mg_dl)>200
ORDER By 2 DESC,3 DESC, 4 DESC, 5 DESC 

--Clients with problem and smoked
Select client_id, 
       AVG(bmi) AS avg_bmi,
	   AVG(bp_systolic) AS avg_systolicBP,
	   AVG(bp_diastolic) AS avg_diastolicBP,
	   AVG(cholesterol_mg_dl) AS avg_cholesterol,
	   smoking_status
From HealthMetrics$
WHERE  smoking_status='Smoker'
Group by client_id,smoking_status
Having AVG(bmi)>30 OR AVG(bp_systolic) >130 OR  AVG(bp_diastolic)>80 OR AVG(cholesterol_mg_dl)>200 
ORDER By 2 DESC,3 DESC, 4 DESC, 5 DESC 
--OUTCOMES
--Satisfaction Score
Select AVG(satisfaction_score) AS avg_SatisfactionScore
From SatisfactionSurveys$
Where survey_date BETWEEN '2025-01-01' AND '2025-12-31'

-- Completion rate and average feedback score by program
SELECT pr.program_name,
      100.0* SUM(CASE WHEN pp.completion_status = 'Completed' THEN 1 ELSE 0 END) / 
       COUNT(*) AS completion_rate,
       AVG(pp.feedback_score) AS avg_feedback
FROM ProgramParticipants$ pp
JOIN Programs$ pr ON pp.program_id = pr.program_id
GROUP BY pr.program_name
ORDER BY completion_rate DESC;

--------Correlation between engagement and satisfaction--------

-- Average engagement metrics per client
SELECT client_id,
       AVG(messages_sent)     AS avg_messages,
       AVG(journal_entries)   AS avg_journals,
       AVG(metrics_logged)    AS avg_metrics
FROM Engagement$
GROUP BY client_id;

-- Join engagement with satisfaction scores to see correlation
WITH engagement_summary AS (
    SELECT client_id,
           AVG(messages_sent)   AS avg_messages,
           AVG(journal_entries) AS avg_journals,
           AVG(metrics_logged)  AS avg_metrics
    FROM Engagement$
    GROUP BY client_id
)
SELECT e.client_id,
       e.avg_messages,
       e.avg_journals,
       e.avg_metrics,
       AVG(s.satisfaction_score) AS avg_satisfaction
FROM engagement_summary e
LEFT JOIN SatisfactionSurveys$ s
  ON e.client_id = s.client_id
GROUP BY e.client_id, e.avg_messages, e.avg_journals, e.avg_metrics
ORDER BY avg_satisfaction DESC;

--------Correlation between Marketing cost vs Conversions vs ROI--------

--Which marketing channel gives the best conversions per cost, and best ROI?
SELECT
    channel,
    SUM(leads_count) AS total_leads,
    SUM(conversions) AS total_conversions,
    SUM(cost) AS total_cost,
    CAST(SUM(cost) AS FLOAT) / NULLIF(SUM(conversions), 0) AS cost_per_conversion,
    CAST(SUM(conversions) AS FLOAT) / NULLIF(SUM(leads_count), 0) AS conversion_rate
FROM MarketingLeads$
GROUP BY channel
ORDER BY cost_per_conversion ASC;
--Connect marketing to revenue (approx using appointment revenue by month)
WITH marketing_month AS (
    SELECT
        DATEFROMPARTS(YEAR(lead_date), MONTH(lead_date), 1) AS [month],
        SUM(cost) AS marketing_cost,
        SUM(conversions) AS conversions
    FROM MarketingLeads$
    GROUP BY DATEFROMPARTS(YEAR(lead_date), MONTH(lead_date), 1)
),
revenue_month AS (
    SELECT
        DATEFROMPARTS(YEAR(appointment_date), MONTH(appointment_date), 1) AS [month],
        SUM(revenue) AS appointment_revenue
    FROM Appointments$
    WHERE status = 'Attended'
    GROUP BY DATEFROMPARTS(YEAR(appointment_date), MONTH(appointment_date), 1)
)
SELECT
    m.[month],
    m.marketing_cost,
    m.conversions,
    r.appointment_revenue,
    (r.appointment_revenue - m.marketing_cost) AS approx_profit_after_marketing
FROM marketing_month m
LEFT JOIN revenue_month r
    ON r.[month] = m.[month]
	ORDER BY m.[month];
