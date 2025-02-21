--Query 01: calculate total visit, pageview, transaction for Jan, Feb AND March 2017 (order by month)
SELECT
    FORMAT_DATE("%Y%m",PARSE_DATE('%Y%m%d',date)) AS month,
    SUM(totals.visits) AS visits,
    SUM(totals.pageviews) AS pageviews,
    SUM(totals.transactions) AS transactions,
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _table_suffix BETWEEN '0101' AND '0331'
GROUP BY month
ORDER BY month;
--correct

--Query 02: Bounce rate per traffic source in July 2017 (Bounce_rate = num_bounce/total_visit) (order by total_visit DESC)
SELECT
    trafficSource.source,
    SUM(totals.visits) AS total_visits,
    SUM(totals.bounces) AS total_no_of_bounces,
    ROUND(SUM(totals.bounces)/SUM(totals.visits)*100, 3) AS Bounce_rate
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` 
Where _table_suffix BETWEEN '0701' AND '0731'
GROUP BY trafficSource.source
ORDER BY total_visits DESC;
--correct

--Query 3: Revenue by traffic source by week, by month in June 2017
SELECT
    'WEEK'AS time_type,
    FORMAT_DATE("%Y%W",PARSE_DATE('%Y%m%d',date)) AS week,
    trafficSource.source AS source,
    SUM(productRevenue)/1000000 AS revenue
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` 
    ,UNNEST (hits) hits,
    UNNEST(product) product
Where _table_suffix BETWEEN '0601' AND '0630'
    AND product.productRevenue IS NOT NULL
GROUP BY week, source 
UNION ALL
SELECT
    'MONTH'AS time_type,
    FORMAT_DATE("%Y%m",PARSE_DATE('%Y%m%d',date)) AS month,
    trafficSource.source AS source,
    SUM(productRevenue)/1000000 AS revenue
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` 
    ,UNNEST (hits) hits,
    UNNEST(product) product
Where _table_suffix BETWEEN '0601' AND '0630'
    AND product.productRevenue IS NOT NULL
GROUP BY month, source  
ORDER BY revenue DESC;

--mình có thể trình bày theo kiểu CTE cho dễ nhìn hơn
with 
month_data as(
  SELECT
    "Month" as time_type,
    format_date("%Y%m", parse_date("%Y%m%d", date)) as month,
    trafficSource.source AS source,
    SUM(p.productRevenue)/1000000 AS revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
    unnest(hits) hits,
    unnest(product) p
  WHERE p.productRevenue is not null
  GROUP BY 1,2,3
  order by revenue DESC
),

week_data as(
  SELECT
    "Week" as time_type,
    format_date("%Y%W", parse_date("%Y%m%d", date)) as week,
    trafficSource.source AS source,
    SUM(p.productRevenue)/1000000 AS revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
    unnest(hits) hits,
    unnest(product) p
  WHERE p.productRevenue is not null
  GROUP BY 1,2,3
  order by revenue DESC
)

select * from month_data
union all
select * from week_data;
order by time_type
--nên order by time_type, để month vs week đc xếp thành các cụm riêng biệt


--Query 04: Average number of pageviews by purchaser type (purchasers vs non-purchasers) in June, July 2017.
WITH 
purchaser_data AS(
  SELECT
      FORMAT_DATE("%Y%m",PARSE_DATE("%Y%m%d",date)) AS month,
      (SUM(totals.pageviews)/COUNT(DISTINCT fullvisitorid)) AS avg_pageviews_purchase,
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
    ,UNNEST(hits) hits
    ,UNNEST(product) product
  WHERE _table_suffix BETWEEN '0601' AND '0731'
  AND totals.transactions>=1
  AND product.productRevenue is not null
  GROUP BY month
),
non_purchaser_data as(
  SELECT
      FORMAT_DATE("%Y%m",PARSE_DATE("%Y%m%d",date)) AS month,
      SUM(totals.pageviews)/COUNT(DISTINCT fullvisitorid) AS avg_pageviews_non_purchase,
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
      ,UNNEST(hits) hits
    ,UNNEST(product) product
  WHERE _table_suffix BETWEEN '0601' AND '0731'
  AND totals.transactions is null
  AND product.productRevenue is null
  GROUP BY month
)
SELECT
    pd.*,
    avg_pageviews_non_purchase
FROM purchaser_data pd
LEFT JOIN non_purchaser_data USING(month)   --> full join
ORDER BY pd.month;

--câu 4 này lưu ý là mình nên dùng full join, bởi vì trong câu này, phạm vi chỉ từ tháng 6-7, nên chắc chắc sẽ có pur và nonpur của cả 2 tháng
--mình inner join thì vô tình nó sẽ ra đúng. nhưng nếu đề bài là 1 khoảng thời gian dài hơn, 2-3 năm chẳng hạn, nó cũng tháng chỉ có nonpur mà k có pur
--thì khi đó inner join nó sẽ làm mình bị mất data, thay vì hiện số của nonpur và pur thì nó để trống

--Query 05: Average number of transactions per user that made a purchase in July 2017
SELECT
    FORMAT_DATE("%Y%m",PARSE_DATE('%Y%m%d',date)) AS month,
    SUM(totals.transactions)/COUNT(DISTINCT fullVisitorid) AS avg_total_transactions_per_user
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
    ,UNNEST (hits) hits,
    UNNEST(product) product
Where 
    _table_suffix BETWEEN '0701' AND '0731'
    AND totals.transactions >= 1
    AND totals.totalTransactionRevenue IS NOT NULL
    AND product.productRevenue IS NOT NULL
GROUP BY month;

--correct

--Query 06: Average amount of money spent per session. Only include purchaser data in July 2017
SELECT 
  FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) month,
  ROUND((SUM(product.productRevenue) / SUM(totals.visits))/1000000,2) avg_revenue_by_user_per_visit
FROM 
  `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`, 
  UNNEST(hits) hits, 
  UNNEST(hits.product) product
WHERE 
  _TABLE_SUFFIX BETWEEN '0701' AND '0731'
  AND product.productRevenue IS NOT NULL
  AND totals.transactions IS NOT NULL
GROUP BY month;
--correct

--Query 07: Other products purchased by customers who purchased product "YouTube Men's Vintage Henley" in July 2017. Output should show product name and the quantity was ordered.
WITH product as (
    SELECT
        fullVisitorId,
        product.v2ProductName,
        product.productRevenue,
        product.productQuantity 
    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`,
        UNNEST(hits) AS hits,
        UNNEST(hits.product) AS product
    Where 
        _table_suffix between '20170701' and '20170731'
        AND product.productRevenue IS NOT NULL
)
SELECT
    product.v2ProductName as other_purchased_products,
    SUM(product.productQuantity) as quantity
FROM product
WHERE 
    product.fullVisitorId IN (
        SELECT fullVisitorId
        FROM product
        WHERE product.v2ProductName LIKE "YouTube Men's Vintage Henley"

    )
    AND product.v2ProductName NOT LIKE "YouTube Men's Vintage Henley"
GROUP BY other_purchased_products
ORDER BY quantity DESC;

--khi lấy điều kiện chính xác như 'Youtube....' thì nên dùng dấu = hoặc in hoặc <>, k nên dùng like, thì like thường dùng để tìm kiếm gần giống

--subquery:
select
    product.v2productname as other_purchased_product,
    sum(product.productQuantity) as quantity
from `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
    unnest(hits) as hits,
    unnest(hits.product) as product
where fullvisitorid in (select distinct fullvisitorid
                        from `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
                        unnest(hits) as hits,
                        unnest(hits.product) as product
                        where product.v2productname = "YouTube Men's Vintage Henley"
                        and product.productRevenue is not null)
and product.v2productname != "YouTube Men's Vintage Henley"
and product.productRevenue is not null
group by other_purchased_product
order by quantity desc;

--CTE:
--ở bảng buyer_list này, mình chỉ muốn tìm ra danh sách nhưng ng mua, thì nó người ngta sẽ mua nhiều lần chẳng hặn
--khi mình select distinct fullVisitorId, nó sẽ 3 người, nhưng nếu mình select fullVisitorId
--nó ra 6 dòng, tường ứng với 6 record trong bảng, rồi nó mang 6 dòng này, đi mapping tiếp với câu dưới, nên nó bị dup lên

with buyer_list as(
    SELECT
        distinct fullVisitorId
    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
    , UNNEST(hits) AS hits
    , UNNEST(hits.product) as product
    WHERE product.v2ProductName = "YouTube Men's Vintage Henley"
    AND totals.transactions>=1
    AND product.productRevenue is not null
)

SELECT
  product.v2ProductName AS other_purchased_products,
  SUM(product.productQuantity) AS quantity
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
, UNNEST(hits) AS hits
, UNNEST(hits.product) as product
JOIN buyer_list using(fullVisitorId)
WHERE product.v2ProductName != "YouTube Men's Vintage Henley"
 and product.productRevenue is not null
GROUP BY other_purchased_products
ORDER BY quantity DESC;




--"Query 08: Calculate cohort map from product view to addtocart to purchase in Jan, Feb and March 2017. For example, 100% product view then 40% add_to_cart and 10% purchase.
WITH cohort_data AS (
  SELECT
    FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
    COUNTIF(hits.eCommerceAction.action_type = '2') AS num_product_view,
    COUNTIF(hits.eCommerceAction.action_type = '3') AS num_addtocart,
    COUNTIF(hits.eCommerceAction.action_type = '6' AND product.productRevenue IS NOT NULL) AS num_purchase
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
    UNNEST(hits) AS hits,
    UNNEST(hits.product) AS product
  WHERE _table_suffix BETWEEN '0101' AND '0331'
  GROUP BY month
)
SELECT
  month,
  num_product_view,
  num_addtocart,
  num_purchase,
  ROUND((num_addtocart * 100.0) / num_product_view, 2) AS add_to_cart_rate,
  ROUND((num_purchase * 100.0) / num_product_view, 2) AS purchase_rate
FROM cohort_data
ORDER BY month;

--bài yêu cầu tính số sản phầm, mình nên count productName hay productSKU thì sẽ hợp lý hơn là count action_type
--k nên xài inner join, nếu table1 có 10 record,table2 có 5 record,table3 có 1 record, thì sau khi inner join, output chỉ ra 1 record

--Cách 1:dùng CTE
with
product_view as(
  SELECT
    format_date("%Y%m", parse_date("%Y%m%d", date)) as month,
    count(product.productSKU) as num_product_view
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
  , UNNEST(hits) AS hits
  , UNNEST(hits.product) as product
  WHERE _TABLE_SUFFIX BETWEEN '20170101' AND '20170331'
  AND hits.eCommerceAction.action_type = '2'
  GROUP BY 1
),

add_to_cart as(
  SELECT
    format_date("%Y%m", parse_date("%Y%m%d", date)) as month,
    count(product.productSKU) as num_addtocart
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
  , UNNEST(hits) AS hits
  , UNNEST(hits.product) as product
  WHERE _TABLE_SUFFIX BETWEEN '20170101' AND '20170331'
  AND hits.eCommerceAction.action_type = '3'
  GROUP BY 1
),

purchase as(
  SELECT
    format_date("%Y%m", parse_date("%Y%m%d", date)) as month,
    count(product.productSKU) as num_purchase
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
  , UNNEST(hits) AS hits
  , UNNEST(hits.product) as product
  WHERE _TABLE_SUFFIX BETWEEN '20170101' AND '20170331'
  AND hits.eCommerceAction.action_type = '6'
  and product.productRevenue is not null   --phải thêm điều kiện này để đảm bảo có revenue
  group by 1
)

select
    pv.*,
    num_addtocart,
    num_purchase,
    round(num_addtocart*100/num_product_view,2) as add_to_cart_rate,
    round(num_purchase*100/num_product_view,2) as purchase_rate
from product_view pv
left join add_to_cart a on pv.month = a.month
left join purchase p on pv.month = p.month
order by pv.month;

--bài này k nên inner join, vì nếu như bảng purchase k có data thì sẽ k mapping đc vs bảng productview, từ đó kết quả sẽ k có luôn, mình nên dùng left join
--lấy số product_view làm gốc, nên mình sẽ left join ra 2 bảng còn lại

--Cách 2: bài này mình có thể dùng count(case when) hoặc sum(case when)

with product_data as(
select
    format_date('%Y%m', parse_date('%Y%m%d',date)) as month,
    count(CASE WHEN eCommerceAction.action_type = '2' THEN product.v2ProductName END) as num_product_view,
    count(CASE WHEN eCommerceAction.action_type = '3' THEN product.v2ProductName END) as num_add_to_cart,
    count(CASE WHEN eCommerceAction.action_type = '6' and product.productRevenue is not null THEN product.v2ProductName END) as num_purchase
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
,UNNEST(hits) as hits
,UNNEST (hits.product) as product
where _table_suffix between '20170101' and '20170331'
and eCommerceAction.action_type in ('2','3','6')
group by month
order by month
)

select
    *,
    round(num_add_to_cart/num_product_view * 100, 2) as add_to_cart_rate,
    round(num_purchase/num_product_view * 100, 2) as purchase_rate
from product_data;



                                                            --very good---