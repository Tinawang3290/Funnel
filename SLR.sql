-- The table has about 100K distinct rows.

WITH apps AS (
SELECT
  stage_start_date_pst,
  fe1.stage,
  app_starts,
  application_uuid_value,
  fe1.stage_num,
  age,
  CAST(fico_score AS INT64) AS fico_score,
  soft_fico_score,
  state_code,
  CAST(application_amount AS FLOAT64) AS application_amount,
  identity_uuid_value,
  app_start_date,
  is_direct_mail,
  dm_campaign_source,
  stage_entry_ts
FROM
  (SELECT DISTINCT stage_num, stage FROM `reporting.f_slr_figure_funnel_event`) fe1
LEFT JOIN (
-- 
SELECT
             app.stage,
             app.stage_num,
             aps.app_starts,
             f.application_uuid_value,
             app.identity_uuid_value,
             DATE_TRUNC(DATE(stage_entry_ts, 'America/Los_Angeles'),DAY) stage_start_date_pst,
             DATE_DIFF(CAST(app_start_date AS DATE),CAST(dob AS DATE),year) AS age,
             app.hard_fico_score AS fico_score,
             app.soft_fico_score,
             app.state AS state_code,
             app.loan_amount AS application_amount,
             stage_entry_ts,
             app.app_start_date,
             'Need to update ' AS is_direct_mail,
             'Need to update' AS dm_campaign_source
           FROM
             `reporting.f_slr_figure_funnel_event` f
           JOIN
              `reporting.lkup_slr_application` app ON (app.stage = f.stage AND f.application_uuid_value = app.application_uuid_value)
           JOIN
             (SELECT application_uuid_value, 1 app_starts FROM `reporting.f_slr_figure_funnel_event` WHERE stage = 'App Start') aps ON (app.application_uuid_value = aps.application_uuid_value)
           
          ) i ON i.stage = fe1.stage
)
SELECT
  a.*,
  l.organization,
  CASE
    WHEN a.stage = 'Product Select' AND a.application_uuid_value IN (SELECT application_uuid_value FROM reporting.f_slr_figure_funnel_event WHERE stage = 'Declined' AND previous_stage IN ('Product Select','App Start', 'Initial') ) THEN 'Hide'
    WHEN a.stage = 'Tradelines Select' AND a.application_uuid_value IN (SELECT application_uuid_value FROM reporting.f_slr_figure_funnel_event WHERE stage = 'Declined' AND previous_stage IN ('Product Select','App Start', 'Initial','Tradelines Select') ) THEN 'Hide'
    ELSE 'Show'
  END AS decline_filter
FROM
  apps a
JOIN
  reporting.lkup_slr_application l ON a.application_uuid_value = l.application_uuid_value
  
  Tableau Reporting Portion key points:
  
 -- First: Create a Parameter named 'Funnel Metric' with two values as below: 
  Applications and Individuals in string format.
  
  -- Alternatively, create another Parameter titled 'Funnel Metric(Aging)' with values as below:
  Applications; Individuals; Properties; App Amount in string format 
  
  -- Second: Create a calculated data field named 'Funnel Metric' with the formula as below:
  
  CASE [Parameters].[Funnel Metric]
    WHEN "Applications" THEN COUNTD([Application Uuid Value])
    WHEN "Individuals" THEN COUNTD([Identity Uuid Value])
END
  
-- Create a calculated data field titled: Conversion % with the below formula:
  1+((ZN([Funnel Metric]) - LOOKUP(ZN([Funnel Metric]), -1)) / ABS(LOOKUP(ZN([Funnel Metric]), -1)))
  
-- Alternatively, create a calculated data field named: Date Filter with the below formula:
  IF [App Start Date] >= DATE("2019-10-01") THEN 'Show' ELSE 'Hide Test Apps' END
  
-- Create a Parameter named 'Stage Toggle' with the below formula(use if, elif, end for multiple conditions):

IF [Approved Toggle] = 'combined' AND ([stage_completion_filter] = 'Approved' OR [stage_completion_filter] = 'Cancelled') THEN 'Approved'
ELSEIF [Approved Toggle] = 'cancel' AND ([stage_completion_filter] = 'Approved' OR [stage_completion_filter] = 'Cancelled') THEN [stage_completion_filter]
ELSE [stage_completion_filter]
END

-- Create a calculated data field named 'Stage Toggle' with the below formula:

IF [Approved Toggle] = 'combined' AND ([stage_completion_filter] = 'Approved' OR [stage_completion_filter] = 'Cancelled') THEN 'Approved'
ELSEIF [Approved Toggle] = 'cancel' AND ([stage_completion_filter] = 'Approved' OR [stage_completion_filter] = 'Cancelled') THEN [stage_completion_filter]
ELSE [stage_completion_filter]
END

-- Set up a parameter named 'Max Stage Age' with the current max value of 14 and another parameter named 'Stage Age Param' with the min value of 1.
Allowable values: All. / Data type: Integer.

-- Create measure calculated data field named '% of Total' with the below formula:
SUM([Number of Records])/[Total App Starts]

-- Create measure calculated data field named 'App Amount' with the below formula:
IF [Stage] = 'App Start' OR [Stage] = 'Quality Start' OR [Stage] = 'Product Select' OR [Stage] = 'Initial' OR [Stage] = 'No Soft Credit' THEN null
ELSE [App Amount]
END

-- Create a Parameter named 'Trend Measure' with the below formula:
CASE [Parameters].[Trend Measure]
    WHEN 'Funnel Counts' THEN [Funnel Metric]
    WHEN 'App Amount ($)' THEN SUM([App Amount (reporting)])
//    WHEN '% of Total' THEN [% of Total]
END

-- Create a calculated data field named 'Trend Measure Moving Average Daily' with the below formula:
WINDOW_AVG(([Trend Measure]),-[Days of Moving Average]+1,0)

-- Create a calculated data field named 'Trend Measure Moving Average Weekly' with the below formula:
WINDOW_AVG(([Trend Measure]),-[Weeks of Moving Average]+1,0)
Note: About Window_Avg function in Tableau: https://help.tableau.com/current/pro/desktop/en-us/functions_functions_tablecalculation.htm

-- Create a Measure calculated data field named 'Efficiency -- previous stage to next stage' with the formula as below:
ZN(sum(next stage)/sum(previous stage))

E.g.: 'Efficiency - Bank to Notary'
ZN(SUM([Notary])/sum([Bank Account]))

Note: ZN()function in Tableau is  a variation on the ISNULL and IFNULL function. 
ZN tests to see if a function is null, and if it is, it will return a value of zero

-- If need any apps to be excluded, we can add the data field named 'Test App Exclusion' with the below formula:
E.g.: 
IF [Application Uuid Value] = 'd44f9dc1-c72c-4e66-a358-37d78f6d2199' 
OR [Application Uuid Value] = 'a9c60543-2582-4de8-99a4-3c0ded66c25f'
THEN 'Exclude'
END


