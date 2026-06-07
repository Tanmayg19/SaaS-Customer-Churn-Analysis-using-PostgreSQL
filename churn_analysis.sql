CREATE TABLE transactions (
transaction_id INT PRIMARY KEY,
customer_id INT,
amount float,
transaction_date DATE);	

CREATE TABLE user_activity(
activity_id INT PRIMARY KEY,
customer_id INT,
event_type VARCHAR(20),
event_date DATE
);

CREATE TABLE customers (
customer_id INT PRIMARY KEY,
name VARCHAR(30),
email VARCHAR(50),
signup_date DATE,
country VARCHAR (55)
);

CREATE TABLE subscriptions (
subscription_id INT PRIMARY KEY,
customer_id INT,
plan_type VARCHAR (10),
start_date DATE,
end_date DATE,
status VARCHAR (10)
)

select * from customers
select * from user_activity
select * from transactions order by transaction_date DESC
select * from subscriptions

select 
	count(distinct customer_id) as no_of_customers
from customers;

--- Find financial churn (who stopped paying ) - LAST payment date for each customer

SELECT customer_id, 
MAX(transaction_date) as last_payment_date
FROM transactions
GROUP BY customer_id
ORDER BY last_payment_date

-- filter out these customers who haven't made a payment in the last 90 days
SELECT customer_id, 
		MAX(transaction_date) as last_payment_date
FROM transactions
GROUP BY customer_id
HAVING MAX(transaction_date) < 
	(SELECT MAX(transaction_date) 
	FROM transactions
	) - INTERVAL '90 days'
ORDER BY last_payment_date DESC;

-- Finding Engagement Churn (who stopped logging in)

SELECT customer_id, 
		MAX(event_date) as last_login_date
FROM user_activity
WHERE event_type = 'Login'
GROUP BY customer_id
ORDER BY last_login_date DESC

SELECT customer_id,
	MAX(event_date) as last_login_date
FROM user_activity
WHERE event_type = 'Login'
GROUP BY customer_id
HAVING MAX(event_date) < (
	SELECT MAX(event_date)
	FROM user_activity) - INTERVAL '90 days'
ORDER BY last_login_date DESC

------ silent churn folks (who pays but doesnt log in)----

SELECT t.customer_id, 
	MAX(t.transaction_date) as last_payment_date,
	MAX(u.event_date) AS last_login_date 
FROM transactions as t 
LEFT JOIN user_activity as u 
ON t.customer_id = u.customer_id
GROUP BY t.customer_id
HAVING MAX(t.transaction_date) < (SELECT MAX(transaction_date) FROM transactions) - INTERVAL '90 days'
AND MAX(u.event_date) < (SElECT MAX(event_date) FROM user_activity) - INTERVAL '90 days'
ORDER BY last_login_date DESC, last_payment_date ASC


---COMBINE EVERYTHING AND MAKING A FINAL TABLE
SELECT c.customer_id, 
	c.name,
	c.email,
	CASE WHEN t.customer_id IS NOT NULL THEN 'Financial Churn'
		WHEN ua.customer_id IS NOT NULL THEN 'Engagement_churn'
		WHEN sc.customer_id IS NOT NULL THEN 'Silent Churn'
		ELSE 'Active'
		END AS Churn_type
FROM customers as c
LEFT JOIN
	(SELECT customer_id, MAX(transaction_date) as last_login_date
	FROM transactions
	GROUP BY customer_id
	HAVING MAX(transaction_date) < (SELECT MAX(transaction_date) FROM transactions) - INTERVAL '90 days') as t
	ON c.customer_id = t.customer_id
LEFT JOIN (
	SELECT customer_id, MAX(event_date) as last_login_date
	FROM user_activity 
	GROUP BY customer_id
	HAVING MAX(event_date) < (SELECT MAX(event_date) FROM user_activity) - INTERVAL '90 days') as ua
	ON c.customer_id = ua.customer_id
LEFT JOIN
	(SELECT t.customer_id, 
	MAX(t.transaction_date) as last_payment_date,
	MAX(u.event_date) AS last_login_date 
	FROM transactions as t 
	LEFT JOIN user_activity as u 
	ON t.customer_id = u.customer_id
	GROUP BY t.customer_id
	HAVING MAX(t.transaction_date) < (SELECT MAX(transaction_date) FROM transactions) - INTERVAL '90 days'
	AND MAX(u.event_date) < (SElECT MAX(event_date) FROM user_activity) - INTERVAL '90 days') as sc
	ON c.customer_id = sc.customer_id
ORDER BY c.customer_id

----------------Checking the subscriptions status-------
WITH churn_data AS (
SELECT c.customer_id, 
	c.name,
	c.email,
	CASE WHEN t.customer_id IS NOT NULL THEN 'Financial Churn'
		WHEN ua.customer_id IS NOT NULL THEN 'Engagement_churn'
		WHEN sc.customer_id IS NOT NULL THEN 'Silent Churn'
		ELSE 'Active'
		END AS Churn_type
FROM customers as c
LEFT JOIN
	(SELECT customer_id, MAX(transaction_date) as last_login_date
	FROM transactions
	GROUP BY customer_id
	HAVING MAX(transaction_date) < (SELECT MAX(transaction_date) FROM transactions) - INTERVAL '90 days') as t
	ON c.customer_id = t.customer_id
LEFT JOIN (
	SELECT customer_id, MAX(event_date) as last_login_date
	FROM user_activity 
	GROUP BY customer_id
	HAVING MAX(event_date) < (SELECT MAX(event_date) FROM user_activity) - INTERVAL '90 days') as ua
	ON c.customer_id = ua.customer_id
LEFT JOIN
	(SELECT t.customer_id, 
	MAX(t.transaction_date) as last_payment_date,
	MAX(u.event_date) AS last_login_date 
	FROM transactions as t 
	LEFT JOIN user_activity as u 
	ON t.customer_id = u.customer_id
	GROUP BY t.customer_id
	HAVING MAX(t.transaction_date) < (SELECT MAX(transaction_date) FROM transactions) - INTERVAL '90 days'
	AND MAX(u.event_date) < (SElECT MAX(event_date) FROM user_activity) - INTERVAL '90 days') as sc
	ON c.customer_id = sc.customer_id
ORDER BY c.customer_id),

latest_subscriptions AS(
	SELECT 
		customer_id, 
		plan_type, 
		status,
		end_date,
		ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date DESC) as rnk
	FROM subscriptions)

SELECT ch.*, s.plan_type, s.status, s.end_date 
FROM churn_data AS ch
LEFT JOIN latest_subscriptions AS s
ON ch.customer_id =  s.customer_id
AND s.rnk = 1
ORDER BY ch.customer_id;