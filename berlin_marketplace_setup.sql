select * from orders
limit 10;

ALTER TABLE orders 
ALTER COLUMN Order_Purchase_Timestamp TYPE TIMESTAMP 
USING Order_Purchase_Timestamp::TIMESTAMP,
ALTER COLUMN Order_Delivered_Customer_Date TYPE TIMESTAMP 
USING Order_Delivered_Customer_Date::TIMESTAMP;

select * from orders limit 10;

-- Converting the remaining logistical timestamps
ALTER TABLE orders 
ALTER COLUMN Order_Approved_At TYPE TIMESTAMP 
USING Order_Approved_At::TIMESTAMP,
ALTER COLUMN Order_Delivered_Carrier_Date TYPE TIMESTAMP 
USING Order_Delivered_Carrier_Date::TIMESTAMP,
ALTER COLUMN Order_Estimated_Delivery_Date TYPE TIMESTAMP 
USING Order_Estimated_Delivery_Date::TIMESTAMP;

CREATE TABLE order_items (
    Order_ID TEXT,
    Order_Item_ID INT,
    Product_ID TEXT,
    Seller_ID TEXT,
    Shipping_Limit_Date TEXT,
    Price DECIMAL,
    Freight_Value DECIMAL
);

SELECT SUM(Price) AS total_revenue_raw FROM order_items;

-- 1. Customers
CREATE TABLE customers (
    Customer_Trx_ID TEXT,
    Subscriber_ID TEXT,
    Subscribe_Date TEXT,
    First_Order_Date TEXT,
    Customer_Postal_Code TEXT,
    Customer_City TEXT,
    Customer_Country TEXT,
    Customer_Country_Code TEXT,
    Age TEXT,
    Gender TEXT
);

-- 2. Sellers
CREATE TABLE sellers (
    Seller_ID TEXT,
    Seller_Name TEXT,
    Seller_Postal_Code TEXT,
    Seller_City TEXT,
    Country_Code TEXT,
    Seller_Country TEXT
);

-- 3. Products
CREATE TABLE products (
    Product_ID TEXT,
    Product_Category_Name TEXT,
    Product_Weight_Gr TEXT,
    Product_Length_Cm TEXT,
    Product_Height_Cm TEXT,
    Product_Width_Cm TEXT
);

-- 4. Order Payments
CREATE TABLE order_payments (
    Order_ID TEXT,
    Payment_Sequential TEXT,
    Payment_Type TEXT,
    Payment_Installments TEXT,
    Payment_Value TEXT
);

-- 5. Geolocations
CREATE TABLE geolocations (
    Geo_Postal_Code TEXT,
    Geo_Lat TEXT,
    Geo_Lon TEXT,
    Geolocation_City TEXT,
    Geo_Country TEXT
);

-- 6. Order Reviews
CREATE TABLE order_reviews (
    Review_ID TEXT,
    Order_ID TEXT,
    Review_Score TEXT,
    Review_Comment_Title_En TEXT,
    Review_Comment_Message_En TEXT,
    Review_Creation_Date TEXT,
    Review_Answer_Timestamp TEXT
);

SELECT 'orders' AS table_name, COUNT(*) AS total_rows FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'geolocations', COUNT(*) FROM geolocations
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews;

--Cleaning up to assign corrrect data types

-- Convert Order Payments
ALTER TABLE order_payments 
ALTER COLUMN Payment_Value TYPE DECIMAL USING Payment_Value::DECIMAL,
ALTER COLUMN Payment_Installments TYPE INT USING Payment_Installments::INTEGER,
ALTER COLUMN Payment_Sequential TYPE INT USING Payment_Sequential::INTEGER;

-- Convert Order Reviews
ALTER TABLE order_reviews 
ALTER COLUMN Review_Score TYPE INT USING Review_Score::INTEGER,
ALTER COLUMN Review_Creation_Date TYPE TIMESTAMP USING Review_Creation_Date::TIMESTAMP,
ALTER COLUMN Review_Answer_Timestamp TYPE TIMESTAMP USING Review_Answer_Timestamp::TIMESTAMP;

-- Convert Products (Weights and Measures)
ALTER TABLE products 
ALTER COLUMN Product_Weight_Gr TYPE FLOAT USING Product_Weight_Gr::FLOAT,
ALTER COLUMN Product_Length_Cm TYPE FLOAT USING Product_Length_Cm::FLOAT,
ALTER COLUMN Product_Height_Cm TYPE FLOAT USING Product_Height_Cm::FLOAT,
ALTER COLUMN Product_Width_Cm TYPE FLOAT USING Product_Width_Cm::FLOAT;

-- Convert Order Items (Prices)
ALTER TABLE order_items 
ALTER COLUMN Price TYPE DECIMAL USING Price::DECIMAL,
ALTER COLUMN Freight_Value TYPE DECIMAL USING Freight_Value::DECIMAL,
ALTER COLUMN Order_Item_ID TYPE INT USING Order_Item_ID::INTEGER;

-- Convert Geolocations
ALTER TABLE geolocations 
ALTER COLUMN Geo_Lat TYPE FLOAT USING REPLACE(Geo_Lat, ',', '.')::FLOAT,
ALTER COLUMN Geo_Lon TYPE FLOAT USING REPLACE(Geo_Lon, ',', '.')::FLOAT;

-- Convert Customers
ALTER TABLE customers 
ALTER COLUMN Age TYPE INT USING Age::INTEGER,
ALTER COLUMN Subscribe_Date TYPE DATE USING Subscribe_Date::DATE,
ALTER COLUMN First_Order_Date TYPE DATE USING First_Order_Date::DATE;

-- Database stress test

-- Relational Integrity
SELECT 
    o.Order_ID,
    c.Customer_City,
    s.Seller_City,
    p.Product_Category_Name,
    oi.Price
FROM orders o
JOIN customers c ON o.Customer_Trx_ID = c.Customer_Trx_ID
JOIN order_items oi ON o.Order_ID = oi.Order_ID
JOIN products p ON oi.Product_ID = p.Product_ID
JOIN sellers s ON oi.Seller_ID = s.Seller_ID
LIMIT 10;

-- Null Audit
SELECT 
    'order_items' AS table, 'Price' AS column, COUNT(*) AS null_count FROM order_items WHERE Price IS NULL
UNION ALL
    SELECT 'orders', 'Order_Purchase_Timestamp', COUNT(*) FROM orders WHERE Order_Purchase_Timestamp IS NULL
UNION ALL
    SELECT 'order_payments', 'Payment_Value', COUNT(*) FROM order_payments WHERE Payment_Value IS NULL;

-- Impossible Orders Test
SELECT 
    COUNT(*) AS impossible_orders
FROM orders
WHERE Order_Delivered_Customer_Date < Order_Purchase_Timestamp;

-- (1) Calculating Lead Time Stats for Delivered Orders
SELECT 
    ROUND(AVG(EXTRACT(DAY FROM AGE(Order_Delivered_Customer_Date, Order_Purchase_Timestamp)))::NUMERIC, 2) AS avg_delivery_days,
    
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY EXTRACT(DAY FROM AGE(Order_Delivered_Customer_Date, Order_Purchase_Timestamp)))::NUMERIC, 2) AS percentile_90_delivery_days
    
FROM orders
WHERE Order_Status = 'delivered' 
  AND Order_Delivered_Customer_Date IS NOT NULL;

-- Which cities have the slowest deliveries?

SELECT 
    c.Customer_City,
    ROUND(AVG(EXTRACT(DAY FROM AGE(o.Order_Delivered_Customer_Date, o.Order_Purchase_Timestamp)))::NUMERIC, 2) AS avg_days,
    COUNT(o.Order_ID) AS order_count
FROM orders o
JOIN customers c ON o.Customer_Trx_ID = c.Customer_Trx_ID
WHERE o.Order_Status = 'delivered' 
  AND o.Order_Delivered_Customer_Date IS NOT NULL
GROUP BY c.Customer_City
HAVING COUNT(o.Order_ID) >= 20
ORDER BY avg_days DESC
LIMIT 10;

-- (2) Delivery Accuracy (Promises Vs Reality)

SELECT 
    CASE 
        WHEN o.Order_Delivered_Customer_Date < o.Order_Estimated_Delivery_Date THEN 'Ahead of Schedule'
        WHEN o.Order_Delivered_Customer_Date = o.Order_Estimated_Delivery_Date THEN 'On Time'
        ELSE 'Late'
    
    END AS performance_category,
    COUNT(*) AS total_orders,
    -- This calculates the percentage of the total
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM orders o
WHERE o.Order_Status = 'delivered' 
  AND o.Order_Delivered_Customer_Date IS NOT NULL
GROUP BY 1 
ORDER BY total_orders DESC;

-- (3) Revenue Growth (MoM)

-- Creating a temporary summary of revenue by month
WITH monthly_revenue AS (
    SELECT 
        DATE_TRUNC('month', o.Order_Purchase_Timestamp) AS order_month,
        SUM(oi.Price) AS revenue
    FROM orders o
    JOIN order_items oi ON o.Order_ID = oi.Order_ID
    WHERE o.Order_Status = 'delivered'
    GROUP BY 1
)
-- Compare each month to the one before it
SELECT 
    order_month,
    revenue,
    LAG(revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
    ROUND(
        ((revenue - LAG(revenue) OVER (ORDER BY order_month)) / 
        LAG(revenue) OVER (ORDER BY order_month)) * 100, 2
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY order_month;

-- (4) Logistics Bottlenecks

SELECT 
    s.Seller_Name,
    ROUND(AVG(EXTRACT(DAY FROM AGE(o.Order_Delivered_Carrier_Date, o.Order_Approved_At)))::NUMERIC, 2) AS avg_processing_lag_days,
    COUNT(o.Order_ID) AS total_orders
FROM orders o
JOIN order_items oi ON o.Order_ID = oi.Order_ID
JOIN sellers s ON oi.Seller_ID = s.Seller_ID
WHERE o.Order_Status = 'delivered'
  AND o.Order_Approved_At IS NOT NULL
  AND o.Order_Delivered_Carrier_Date IS NOT NULL
GROUP BY s.Seller_Name
HAVING COUNT(o.Order_ID) >= 10
ORDER BY avg_processing_lag_days DESC
LIMIT 10;

-- (5) Customer Loyalty (Repeat Purchase Rate)

WITH customer_order_counts AS (
    -- Finds every unique human and counts their total orders
    SELECT 
        c.Subscriber_ID,
        COUNT(o.Order_ID) AS order_count
    FROM orders o
    JOIN customers c ON o.Customer_Trx_ID = c.Customer_Trx_ID
    GROUP BY c.Subscriber_ID
)
-- Summarizes those counts into a simple report
SELECT 
    CASE 
        WHEN order_count > 1 THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END AS loyalty_type,
    COUNT(*) AS total_customers,
    ROUND((100.0 * COUNT(*) / SUM(COUNT(*)) OVER())::NUMERIC, 2) AS percentage
FROM customer_order_counts
GROUP BY 1
ORDER BY total_customers DESC;

-- (6) Product Categories 'Profit Vs Popularity'

SELECT 
    p.Product_Category_Name,
    COUNT(oi.Order_ID) AS units_sold,
    ROUND(SUM(oi.Price)::NUMERIC, 2) AS total_revenue,
    ROUND(AVG(oi.Price)::NUMERIC, 2) AS avg_unit_price
FROM order_items oi
JOIN products p ON oi.Product_ID = p.Product_ID
JOIN orders o ON oi.Order_ID = o.Order_ID
WHERE o.Order_Status = 'delivered'
GROUP BY p.Product_Category_Name
ORDER BY total_revenue DESC
LIMIT 10;

-- (7) The 'Review Score' Corrrelation

SELECT 
    COALESCE(NULLIF(p.Product_Category_Name, '#N/A'), 'Uncategorized') AS Product_Category_Name,
	ROUND(AVG(r.Review_Score)::NUMERIC, 2) AS avg_score,
    COUNT(r.Review_ID) AS review_count,
    -- We'll also pull the revenue again to see the scale
    ROUND(SUM(oi.Price)::NUMERIC, 0) AS total_revenue
FROM order_items oi
JOIN products p ON oi.Product_ID = p.Product_ID
JOIN order_reviews r ON oi.Order_ID = r.Order_ID
JOIN orders o ON oi.Order_ID = o.Order_ID
WHERE o.Order_Status = 'delivered'
GROUP BY p.Product_Category_Name
HAVING COUNT(r.Review_ID) >= 50
ORDER BY avg_score ASC -- Show the most hated categories first!
LIMIT 10;

-- (8) Top Performing States

SELECT 
    c.Customer_City,
    COUNT(DISTINCT c.Subscriber_ID) AS unique_customers,
    ROUND(SUM(oi.Price)::NUMERIC, 2) AS total_revenue
FROM orders o
JOIN customers c ON o.Customer_Trx_ID = c.Customer_Trx_ID
JOIN order_items oi ON o.Order_ID = oi.Order_ID
WHERE o.Order_Status = 'delivered'
GROUP BY c.Customer_City
ORDER BY total_revenue DESC;


-- (9) Customer Satisfaction by Payment Type

SELECT 
    p.Payment_Type,
    ROUND(AVG(r.Review_Score)::NUMERIC, 2) AS avg_review_score,
    COUNT(r.Review_ID) AS total_reviews
FROM order_payments p
JOIN order_reviews r ON p.Order_ID = r.Order_ID
GROUP BY p.Payment_Type
ORDER BY avg_review_score DESC;

-- Analysing disparity of review avg between payment and product categories

SELECT 
    CASE WHEN p.Product_Category_Name IS NULL THEN 'Missing Category' ELSE 'Has Category' END AS category_status,
    ROUND(AVG(r.Review_Score)::NUMERIC, 2) AS avg_score,
    COUNT(*) AS total_orders
FROM order_reviews r
LEFT JOIN order_items oi ON r.Order_ID = oi.Order_ID
LEFT JOIN products p ON oi.Product_ID = p.Product_ID
GROUP BY 1;

-- (10) Are heavier products more likely to have bad reviews?

SELECT 
    CASE 
        WHEN p.Product_Weight_Gr < 1000 THEN 'Light (<1kg)'
        WHEN p.Product_Weight_Gr BETWEEN 1000 AND 5000 THEN 'Medium (1-5kg)'
        WHEN p.Product_Weight_Gr > 5000 THEN 'Heavy (>5kg)'
        ELSE 'Unknown Weight'
    END AS weight_class,
    ROUND(AVG(r.Review_Score)::NUMERIC, 2) AS avg_score,
    COUNT(*) AS total_orders
FROM products p
JOIN order_items oi ON p.Product_ID = oi.Product_ID
JOIN order_reviews r ON oi.Order_ID = r.Order_ID
GROUP BY 1
ORDER BY avg_score DESC;

-- (11) Shipping cost efficiency by City

SELECT 
    c.Customer_City,
    ROUND(AVG(oi.Freight_Value)::NUMERIC, 2) AS avg_shipping_cost,
    ROUND(AVG(oi.Price)::NUMERIC, 2) AS avg_item_price,
    ROUND((AVG(oi.Freight_Value) / NULLIF(AVG(oi.Price), 0) * 100)::NUMERIC, 2) AS freight_ratio_pct
FROM customers c
JOIN orders o ON c.Customer_Trx_ID = o.Customer_Trx_ID
JOIN order_items oi ON o.Order_ID = oi.Order_ID
GROUP BY c.Customer_City
HAVING COUNT(o.Order_ID) >= 20
ORDER BY freight_ratio_pct DESC
LIMIT 10;

-- (12) The Review Message Analysis (Delays)

SELECT 
    Review_Score,
    COUNT(*) AS total_reviews,
    SUM(CASE WHEN Review_Comment_Message_en LIKE '%delayed%' 
               OR Review_Comment_Message_en LIKE '%late%' 
               OR Review_Comment_Message_en LIKE '%slow%' THEN 1 ELSE 0 END) AS mentions_delay
FROM order_reviews r
WHERE r.Review_Comment_Message_en IS NOT NULL
GROUP BY Review_Score 
ORDER BY Review_Score DESC;