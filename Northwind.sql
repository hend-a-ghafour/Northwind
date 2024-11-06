USE NORTHWND 

-- Shipped Date Analysis:
SELECT	 OrderID,OrderDate,ShippedDate, ShipVia,Freight
FROM	 Orders 
WHERE	 ShippedDate IS NULL

SELECT	 ProductID , SUM(Quantity) Total_ordered_Quantity
FROM	 [Order Details] OD LEFT JOIN Orders O 
		 ON OD.OrderID=O.OrderID 
WHERE    ShippedDate IS NULL 
GROUP BY ProductID

SELECT	 *
FROM	 Products

/* 
Conclusion:
	1- Regarding the undetermined Shipped Date: The Freight Amount was calculated, 
	   and the Shipping Company was assigned.
	2- The last recorded Date for Order Date & Ship Date was 06-05-1998
	3- In some cases, the total ordered quantity for specific products 
	   (such as ProductID 1, 2, and 7) is greater than the units in stock.
	4- Some products are classified as units on order (such as ProductID 2, 3, and 11),
	   meaning they are awaiting shipment.
Result:
	1- Orders with unspecified Shipping Dates will be considered under shipment.
	2- The null ShippedDate values will be replaced by the average.
*/
 
-- 1- Calculating Net Sales & Profit:
-- Sales Function:
CREATE OR ALTER  FUNCTION [dbo].[N_Sales](@UnitPrice MONEY,@Quantity SMALLINT, @Discount REAL)
	RETURNS MONEY AS
	BEGIN
	RETURN CAST(ROUND((@UnitPrice*@Quantity)*(1-@Discount),2)AS MONEY)
	END

-- Calcualting average days to ship:
SELECT	AVG(DATEDIFF(DD, OrderDate,ShippedDate)) Average_Days_to_Ship 
FROM	Orders

/*
Detailed Net Sales & Profit Report:
	1- Adjusting Dates data types (from Datetime to Date) 
	2- Replacing Shipped date null values with average (8 Days)
	3- Expected Profit = Selling Price (before any discounts)* Quantity Sold
	4- Shipping Status :
		- Shipped	 >> The order has reached its destination.
		- In Transit >> The order was awaiting to be shipped.
*/
CREATE OR ALTER VIEW Revnue_Transactions AS
	SELECT  CAST(O.OrderDate AS DATE) O_Date, CAST(O.RequiredDate AS DATE)  Required_Date, 
			CASE
			WHEN CAST(ShippedDate AS DATE) IS NULL  THEN DATEADD(DAY, 8, CAST(OrderDate AS DATE)) 
			ELSE CAST(ShippedDate AS DATE) 
			END AS Shipped_Date, 
			OD.OrderID O_ID, O.CustomerID C_ID,Country,Discount,
			O.EmployeeID E_ID, OD.ProductID P_ID,OD.Quantity Q,OD.UnitPrice SP ,
			OD.Quantity*OD.UnitPrice Total_Sales,CAST(ROUND(OD.Quantity*OD.UnitPrice*OD.Discount,2)AS MONEY) Discount_Amount,
			dbo.N_Sales(OD.UnitPrice, OD.Quantity,OD.Discount)  Detailed_Net_Sales, 
			CAST(ROUND(dbo.N_Sales(OD.UnitPrice, OD.Quantity,OD.Discount)*.07,2) AS MONEY) Detailed_Net_Profit,
			CAST(ROUND((UnitPrice*Quantity*.07),2)AS MONEY) Expected_Profit,ShipVia,
			CASE
			WHEN CAST(ShippedDate AS DATE) IS NULL  THEN 'In_Transit' 
			ELSE 'Shipped' 
			END AS Shipping_Status
	FROM    [Order Details] AS OD	LEFT JOIN Orders AS O ON OD.OrderID   = O.OrderID
									LEFT JOIN Customers C ON O.CustomerID = C.CustomerID
SELECT	*	 
FROM	Revnue_Transactions

-- Net Sales & Profit per Order:
CREATE OR ALTER VIEW Order_Transactions  AS
	SELECT	YEAR(O_Date) per_Year, MONTH(O_Date)per_Month,O_Date,Required_Date,Shipped_Date,
			CAST(ROUND(DATEDIFF(DD,O_Date,Shipped_Date),2)AS DECIMAL(10,2)) Days_to_Ship,
			O_ID, C_ID,	E_ID,SUM(Q) Quantity_Sold, SUM(Total_Sales) O_Total_Sales,
			SUM(Discount_Amount) O_Discount_Amount,	SUM(Detailed_Net_Sales) O_Net_Sales,
			SUM(Detailed_Net_Profit) O_Net_Profit,Freight, Shipping_Status, RT.ShipVia
	FROM    Revnue_Transactions AS RT LEFT OUTER JOIN Orders AS O 
			ON RT.O_ID = O.OrderID
	GROUP BY YEAR(O_Date),MONTH(O_Date),O_Date,Required_Date,Shipped_Date,DATEDIFF(DD,O_Date,Shipped_Date), O_ID,
			 C_ID, E_ID,Freight,Shipping_Status,RT.ShipVia

SELECT	* 
FROM	Order_Transactions
			   
--Monthly Net Sales & Profit:
CREATE OR ALTER VIEW Monthly_Transactions AS
	SELECT	CAST(YEAR(O_Date)AS NVARCHAR(10))+ '-'+CAST(MONTH(O_Date)AS NVARCHAR(10)) Date_ID,
			MONTH(O_Date) per_Month, YEAR(O_Date) per_Year,COUNT(DISTINCT O_ID) Monthly_Orders,SUM(Q) Monthly_Quantity,
			SUM(Total_Sales) Monthly_Sales,SUM(Discount_Amount) Monthly_Discount, 
			SUM(Detailed_Net_Sales) Monthly_Net_Sales, SUM(Detailed_Net_Profit) Monthly_Net_Profit
			
	FROM	Revnue_Transactions RT 
	GROUP BY MONTH(O_Date) , YEAR(O_Date)

SELECT	*
FROM	Monthly_Transactions

					----------------------------------------------------------------------

-- 2- Customers Report:
-- Annual Net Sales & Profit per Country:
CREATE OR ALTER VIEW Country_Transactions AS
	SELECT	 DISTINCT Country,CAST(YEAR(O_Date)AS NVARCHAR(10))+ '-'+LEFT(Country,3) Country_ID,
			 YEAR(O_Date) Year,SUM(Detailed_Net_Sales) Annual_Sales,SUM(Detailed_Net_Profit) Annual_Profit
	FROM	Revnue_Transactions
	GROUP BY Country, YEAR(O_Date)

SELECT * 
FROM Country_Transactions
ORDER BY Year, Country

-- Note : The following table was created by Python:
SELECT	*
FROM	Country_Growth

ALTER TABLE Country_Growth
ALTER COLUMN COUNTRY NVARCHAR(15) NOT NULL


-- Annual Net Sales & Profit per Country(Totals for specific months):
/*
Note:
	Since the dataset is incomplete(the recorded sales transactions for 1996 started in
	July-1996 and ended in May-1998) :
	1- The sales of 1997(from Jul:Dec) will be compared to the sales of 1996 (The Second Half "H2")
	2- The sales of 1997 (from Jan:Jun) will be compared to the sales of 1998 (The First Half "H1")
*/
CREATE OR ALTER VIEW Country_Transactions_H2 AS
	SELECT	 DISTINCT Country,CAST(YEAR(O_Date)AS NVARCHAR(10))+ 'H2-'+LEFT(Country,3) Country_ID,
			 YEAR(O_Date) Year,SUM(Detailed_Net_Sales) Annual_Sales,SUM(Detailed_Net_Profit) Annual_Profit
	FROM	Revnue_Transactions
	WHERE	YEAR(O_Date)= 1996
	GROUP BY Country, YEAR(O_Date),CAST(YEAR(O_Date)AS NVARCHAR(10))+ 'H2-'+LEFT(Country,3)
	UNION
	SELECT	 DISTINCT Country,CAST(YEAR(O_Date)AS NVARCHAR(10))+ 'H2-'+LEFT(Country,3),
			YEAR(O_Date) Year,SUM(Detailed_Net_Sales) Annual_Sales, SUM(Detailed_Net_Profit) Annual_Profit
	FROM	Revnue_Transactions
	WHERE	YEAR(O_Date)= 1997 AND MONTH(O_Date)>=7
	GROUP BY Country, YEAR(O_Date),CAST(YEAR(O_Date)AS NVARCHAR(10))+ 'H2-'+LEFT(Country,3)

SELECT	*
FROM	Country_Transactions_H2


CREATE OR ALTER VIEW Country_Transactions_H1 AS
	SELECT	 DISTINCT Country,CAST(YEAR(O_Date)AS NVARCHAR(10))+ 'H1-'+LEFT(Country,3) Country_ID,
			 YEAR(O_Date) Year,SUM(Detailed_Net_Sales) Annual_Sales, 
			SUM(Detailed_Net_Profit) Annual_Profit
	FROM	Revnue_Transactions
	WHERE	YEAR(O_Date)= 1997 AND MONTH(O_Date) <=6
	GROUP BY Country, YEAR(O_Date),CAST(YEAR(O_Date)AS NVARCHAR(10))+ 'H1-'+LEFT(Country,3) 
	UNION
	SELECT	 DISTINCT Country, CAST(YEAR(O_Date)AS NVARCHAR(10))+ 'H1-'+LEFT(Country,3) ,
			 YEAR(O_Date) Year,SUM(Detailed_Net_Sales) , SUM(Detailed_Net_Profit) 
	FROM	Revnue_Transactions
	WHERE	YEAR(O_Date)= 1998
	GROUP BY Country, YEAR(O_Date),CAST(YEAR(O_Date)AS NVARCHAR(10))+ 'H1-'+LEFT(Country,3) 

SELECT	*
FROM	Country_Transactions_H1

-- Note : The following table was created by Python:
SELECT	*
FROM	Actual_Country_Growth

ALTER TABLE Actual_Country_Growth
ALTER COLUMN Country NVARCHAR(15) NOT NULL

-- Country YOY Analysis:
SELECT	Country,YOY_97, YOY_98 
FROM	Country_Growth
WHERE Country LIKE 'Belg%' OR Country LIKE 'Den%'

SELECT	* 
FROM	Actual_Country_Growth
WHERE Country LIKE 'Belg%' OR Country LIKE 'Den%'

/*
 - Conclusion (1):
	1- Country Growth Table:
		- Whole Year 1997 vs. Half-Year 1996 and Half-Year 1998
		- The comparison might be skewed due to comparing a full year (1997) with only half-years (1996 and 1998),
		  This can lead to inaccurate growth rate calculations,
	2- Actual Country Growth Table:
		- 1st Half of 1997 vs. 1st Half of 1998 and 2nd Half of 1996 vs. 2nd Half of 1997
		- More Accurate as this comparison aligns the periods more closely by comparing similar halves, 
		  which provides a clearer picture of growth.
		- Comparing like-for-like periods (half-years) makes the growth rate more consistent 
		  and reliable in reflecting actual performance changes.
 - Result:
	The values of "Actual Country Growth" table are more accurate in measuring growth consistently 
	across equivalent periods. 
*/
SELECT	O_Date, Country,Detailed_Net_Sales
FROM	Revnue_Transactions
WHERE Country LIKE 'Pola%'

SELECT	*
FROM	Country_Growth
WHERE Country LIKE 'Pola%'

SELECT	* 
FROM	Actual_Country_Growth
WHERE Country LIKE 'Pola%'		

/*
 - Conclusion (2):
	Year-over-Year (YOY) Growth for "Poland" in the Country Growth Table for 1998 was 544.15%.
	However, in the Actual Country Growth table, the rate was 0%.
	Further analysis revealed that Poland's purchases were concentrated in the second half of 
	1997 and the first half of 1998. As a result, when the data for 1997 is split into these 
	two periods, the high growth in 1998 is offset, leading to a 0% growth rate in the Actual 
	Country Growth table. 
	This highlights how the timing of data can affect growth calculations.
*/


-- Detailed & Summary of Net Sales & Profit per Customer
/* 
 Notes: 
  - The Shipping Cost is assumed to be paid by the customer (Freight will be added to the Customer's Net Purchases).
  - Amount Paid by Customer = Net Purchases + Shipping Cost
*/
CREATE OR ALTER VIEW Customer_Transactions AS
	SELECT	YEAR(RT.O_Date) per_Year,RT.C_ID, LEFT(CompanyName,15) CO_Name, C.Country C_Country,
			RT.O_ID ,sum(Q) Q_Purchased,sum(Total_Sales) Total_Purchases ,sum(Discount_Amount) Discount, 
			sum(Detailed_Net_Sales) Net_Purchases,SUM(Detailed_Net_Profit) Profit_Generated, Freight, 
			(sum(Detailed_Net_Sales) + Freight) Amount_Paid, RT.Shipping_Status
	FROM	Revnue_Transactions RT	LEFT JOIN Customers C ON RT.C_ID = C.CustomerID
									LEFT JOIN Order_Transactions OT ON RT.O_ID =  OT.O_ID
				
	GROUP BY YEAR(RT.O_Date),RT.C_ID, LEFT(CompanyName,15), C.Country,RT.O_ID, Freight,RT.Shipping_Status

SELECT  per_Year,sum(Net_Purchases)
FROM Customer_Transactions
where C_Country like'%norw%'
group by per_Year

-- Repeat & New Customers:
--Customers analysis:
SELECT	COUNT(DISTINCT CustomerID) No_of_Customers
FROM	Customers

SELECT	COUNT(DISTINCT C_ID) No_of_Customers
FROM	Revnue_Transactions
/*
- Conclusion:
	1- The number of customers (at Customer Table)  = 91
	 - No date is provided to indicate when the customer was recorded.
	2- The number of customers (at Revnue_Transactions View) = 89
- Result:
	- Customers will be classified based on the time they placed an order.
	- Out of 91 customers, 89 will be classified as either repeat or new
*/
CREATE OR ALTER VIEW Customer_Classification AS
	SELECT  DISTINCT C_ID,LEFT(CompanyName,15) C_Name,
			CASE 
			WHEN MIN(YEAR(O_Date)) OVER (PARTITION BY C_ID) = 1998 THEN 'New_Customer' 
			ELSE 'Old_Customer' 
			END AS C_Classification
	FROM	Revnue_Transactions RT LEFT JOIN  Customers C
			ON RT.C_ID = C.CustomerID
	GROUP BY C_ID, YEAR(O_Date),LEFT(CompanyName,15)

SELECT	 * 
FROM	 Customer_Classification
ORDER BY C_Classification, C_ID

CREATE OR ALTER VIEW Customer_Summary as
	Select	CAST(per_Year  AS NVARCHAR(5))+'-'+CAST(LEFT(CT.C_ID,2) AS NVARCHAR(5)) Year_ID, per_Year,
			CT.C_ID, CO_Name, C_Country, COUNT(O_ID) Total_Orders,SUM(Q_Purchased) Purchased_Q,
			SUM(Total_Purchases) Purchases, SUM (Discount) Discount ,SUM(Net_Purchases) Net_Purchases,
			SUM(Profit_Generated) Profit_Generated ,SUM (Freight) Freight,
			(SUM(Net_Purchases)+SUM (Freight)) Amount_Paid, C_Classification
	FROM	Customer_Transactions CT LEFT JOIN Customer_Classification CC
			ON CT.C_ID=CC.C_ID
	GROUP BY CAST(per_Year  AS NVARCHAR(5))+'-'+CAST(LEFT(CT.C_ID,2) AS NVARCHAR(5)),per_Year,
			CT.C_ID,CO_Name,C_Country, C_Classification

SELECT	*
FROM	Customer_Summary

					---------------------------------------------------------

-- 3- Product Report:

-- Net Sales & Profit per Product:
CREATE OR ALTER VIEW Product_Transactions AS
	SELECT	CAST(YEAR(O_Date)  AS NVARCHAR(5))+'-'+CAST(P_ID AS NVARCHAR(5)) Year_ID,
			YEAR(O_Date) per_Year,P_ID, LEFT(P.ProductName, 15) AS P_Name,SUM(Q) AS Q_Sold, 
			SUM(Total_Sales) AS P_Sales, SUM(Discount_Amount) P_Discount, 
			SUM(Detailed_Net_Sales) P_Net_Sales,SUM(Detailed_Net_Profit) P_Net_Profit
	FROM    Revnue_Transactions AS RT LEFT OUTER JOIN Products AS P 
			ON  RT.P_ID = P.ProductID
	GROUP BY YEAR(O_Date),P_ID, LEFT(P.ProductName, 15)

SELECT	*
FROM	Product_Transactions
ORDER BY P_ID

-- Product Datails
/*
-- NOTES:
 1- Average Selling Price is calculated by dividing the Total Sales/Product by the Quantity Sold.
 2- Diff_SP was calculated by comparing the Updated Selling Price with the Average Selling Price
 	(Updated_SP - Average_SP)
 3- Reorder level is the point at which businesses order new stock from the supplier.
 4- Discontinued:
	- 1= "True" (the company stopped importing this product).
	- 0= "False" (the company still imports this product).
 5- Stock_Status: 
  - Safe_Stock >> The reorder level is less than the units in stock, and the company hasn't stopped importing this product.  
 					(No Need to take an action regarding restocking at the moment)
 - Restock     >> The reorder level is greater than or equal to the units in stock, and the company hasn't stopped importing this product. 
 					(The products needs to be restocked)
 - Stopped     >> The reorder level is greater than or equal to the units in stock, and the company has stopped importing this product.
					(No Need to take an action regarding restocking)
 - No_Restock >> The reorder level is less than the units in stock, and the company has stopped importing this product.
 					(No Need to take an action regarding restocking when reaching reorder level)
*/

CREATE OR ALTER VIEW Product_Details AS
	SELECT  per_Year,Year_ID,P_ID, P_Name,P.CategoryID Category_ID,LEFT(CategoryName,15) Category, p.SupplierID ,
			LEFT(CompanyName,15) Supplier_Name , Q_Sold, P_Sales, P_Discount,P_Net_Sales,
			CASE
			WHEN per_Year=1996 THEN P_Discount/(SELECT SUM(P_Discount)FROM Product_Transactions WHERE per_Year=1996)
			WHEN per_Year=1997 THEN P_Discount/(SELECT SUM(P_Discount)FROM Product_Transactions WHERE per_Year=1997)
			ELSE P_Discount/(SELECT SUM(P_Discount)FROM Product_Transactions WHERE per_Year=1998)
			END AS Discount_WA,
			CASE
			WHEN per_Year=1996 THEN P_Net_Sales/(SELECT SUM(P_Net_Sales)FROM Product_Transactions WHERE per_Year=1996)
			WHEN per_Year=1997 THEN P_Net_Sales/(SELECT SUM(P_Net_Sales)FROM Product_Transactions WHERE per_Year=1997)
			ELSE P_Net_Sales/(SELECT SUM(P_Net_Sales)FROM Product_Transactions WHERE per_Year=1998)
			END AS NS_pct,
			P_Net_Profit,(P_Sales/Q_Sold) Average_SP, UnitPrice Updated_SP,
			CASE
			WHEN per_Year=1996 THEN P_Net_Sales/(SELECT COUNT(DISTINCT O_ID) FROM Order_Transactions WHERE YEAR(O_Date)=1996)
			WHEN per_Year=1997 THEN P_Net_Sales/(SELECT COUNT(DISTINCT O_ID) FROM Order_Transactions WHERE YEAR(O_Date)=1997)
			ELSE P_Net_Sales/(SELECT COUNT(DISTINCT O_ID) FROM Order_Transactions WHERE YEAR(O_Date)=1998)
			END AS SP_per_Order,
			UnitPrice - (P_Sales/Q_Sold) Diff_SP,UnitsInStock Q_Stock,ReorderLevel Reorder_Level,Discontinued,
			CASE
			WHEN ReorderLevel >= UnitsInStock AND Discontinued = 0 THEN 'Restock'
			WHEN ReorderLevel >= UnitsInStock AND Discontinued = 1 THEN 'Stopped'
			WHEN ReorderLevel <  UnitsInStock AND Discontinued = 0 THEN 'Safe_Stock'
			ELSE 'No_Restock'
			END AS Stock_Status 
	FROM	Product_Transactions PT LEFT JOIN Products P ON PT.P_ID = P.ProductID
									LEFT JOIN Categories C ON P.CategoryID = C.CategoryID
									LEFT JOIN Suppliers S ON P.SupplierID = S.SupplierID

SELECT	*
FROM	Product_Details
ORDER BY P_ID



-- Calculating the weighted averege of each transaction according to each order
CREATE OR ALTER VIEW Weighted_Averages AS
	SELECT	DISTINCT O_Date Order_Date,YEAR(O_Date) per_Year,MONTH(O_Date) per_Month,O_ID Order_ID,RT.P_ID Product_ID,P_Name Product_Name,Category,
			Q,Q/CAST(ROUND(SUM(Q) OVER (PARTITION BY O_ID),2)AS DECIMAL(10,2)) WA_Q,
			SP,SP/(SUM(SP) OVER (PARTITION BY O_ID)) WA_SP,
			Total_Sales,Total_Sales/(SUM(Total_Sales) OVER (PARTITION BY O_ID)) WA_Sales,
			Discount_Amount,
			CASE
			WHEN Discount_Amount = 0 THEN 0 
			ELSE Discount_Amount/(SUM(Discount_Amount) OVER (PARTITION BY O_ID)) 
			END AS WA_Discount, Discount,
			Detailed_Net_Sales,Detailed_Net_Sales/(SUM(Detailed_Net_Sales) OVER (PARTITION BY O_ID)) WA_Net_Sales,
			Detailed_Net_Profit,Detailed_Net_Profit/(SUM(Detailed_Net_Profit) OVER (PARTITION BY O_ID)) WA_Net_Profit
	FROM	Revnue_Transactions RT LEFT JOIN Product_Details PD ON RT.P_ID=PD.P_ID

SELECT	*
FROM	Weighted_Averages


-- Allocating the shipping cost according to the quantity of each product in each order 
CREATE OR ALTER VIEW Allocation AS
	SELECT	CAST(YEAR(Order_Date)AS NVARCHAR(10))+ '-'+CAST(Product_ID AS NVARCHAR(10))+LEFT(Product_Name,2)Year_ID,
			Order_Date,MONTH(Order_Date) per_Month,YEAR(Order_Date)per_Year,Order_ID,Product_ID,
			Product_Name,Category,Q,WA_Q,SP,Total_Sales,Discount_Amount,Discount,
			Detailed_Net_Sales,Detailed_Net_Profit,CAST(ROUND(FREIGHT * WA_Q,2)AS MONEY) Allocated_Freight
	FROM	Weighted_Averages W LEFT JOIN Orders O 
			ON W.Order_ID=O.OrderID

SELECT	*
FROM	Allocation


/*
Notes: 
	Since the dataset is incomplete(the recorded sales transactions for 1996 started in
	July-1996 and ended in May-1998) :
	1- The sales of 1997(from Jul:Dec) will be compared to the sales of 1996 (The Second Half "H2")
	2- The sales of 1997 (from Jan:Jun) will be compared to the sales of 1998 (The First Half "H1")

*/
CREATE OR ALTER VIEW Allocation_H2 AS
	SELECT	CAST(YEAR(Order_Date)AS NVARCHAR(10))+ '-'+CAST(Product_ID AS NVARCHAR(10))+LEFT(Product_Name,2)Year_ID,
			Order_Date,MONTH(Order_Date) per_Month,YEAR(Order_Date)per_Year,Order_ID,Product_ID,
			Product_Name,Category,Q,WA_Q,SP,Total_Sales,Discount_Amount,
			Detailed_Net_Sales,Detailed_Net_Profit,CAST(ROUND(FREIGHT * WA_Q,2)AS MONEY) Allocated_Freight
	FROM	Weighted_Averages W LEFT JOIN Orders O 
			ON W.Order_ID=O.OrderID
	WHERE   YEAR(Order_Date) = 1996
	UNION 
	SELECT	CAST(YEAR(Order_Date)AS NVARCHAR(10))+ '-'+CAST(Product_ID AS NVARCHAR(10))+LEFT(Product_Name,2),
			Order_Date,MONTH(Order_Date) ,YEAR(Order_Date),Order_ID,Product_ID,
			Product_Name,Category,Q,WA_Q,SP,Total_Sales,Discount_Amount,
			Detailed_Net_Sales,Detailed_Net_Profit,CAST(ROUND(FREIGHT * WA_Q,2)AS MONEY) 
	FROM	Weighted_Averages W LEFT JOIN Orders O 
			ON W.Order_ID=O.OrderID
	WHERE   YEAR(Order_Date) = 1997 AND MONTH(Order_Date) >=7

SELECT	*
FROM	Allocation_H2

CREATE OR ALTER VIEW Allocation_H1 AS
	SELECT	CAST(YEAR(Order_Date)AS NVARCHAR(10))+ '-'+CAST(Product_ID AS NVARCHAR(10))+LEFT(Product_Name,2)Year_ID,
			Order_Date,MONTH(Order_Date) per_Month,YEAR(Order_Date)per_Year,Order_ID,Product_ID,
			Product_Name,Category,Q,WA_Q,SP,Total_Sales,Discount_Amount,
			Detailed_Net_Sales,Detailed_Net_Profit,CAST(ROUND(FREIGHT * WA_Q,2)AS MONEY) Allocated_Freight
	FROM	Weighted_Averages W LEFT JOIN Orders O ON W.Order_ID=O.OrderID
								
			
	WHERE   YEAR(Order_Date) = 1997 AND MONTH(Order_Date) <=6
	UNION 
	SELECT	CAST(YEAR(Order_Date)AS NVARCHAR(10))+ '-'+CAST(Product_ID AS NVARCHAR(10))+LEFT(Product_Name,2),
			Order_Date,MONTH(Order_Date) ,YEAR(Order_Date),Order_ID,Product_ID,
			Product_Name,Category,Q,WA_Q,SP,Total_Sales,Discount_Amount,
			Detailed_Net_Sales,Detailed_Net_Profit,CAST(ROUND(FREIGHT * WA_Q,2)AS MONEY) 
	FROM	Weighted_Averages W LEFT JOIN Orders O 
			ON W.Order_ID=O.OrderID
	WHERE   YEAR(Order_Date) = 1998

SELECT	*
FROM	Allocation_H1



-- Product Report per year (Averages):
CREATE OR ALTER VIEW Allocation_Summary AS
	SELECT	DISTINCT YEAR(Order_Date) per_Year,CAST(YEAR(Order_Date)AS NVARCHAR(10))+ '-'+CAST(Product_ID AS NVARCHAR(10))+LEFT(Product_Name,2)Year_ID,
			Product_ID,Product_Name,Category,AVG(Q)OVER (PARTITION BY Product_ID ORDER BY YEAR(Order_Date)) Quantity_SOld,
			CAST(ROUND(AVG(SP) OVER (PARTITION BY Product_ID ORDER BY YEAR(Order_Date)),2)AS MONEY)Product_Avg_Price,
			CAST(ROUND(AVG(Total_Sales) OVER (PARTITION BY Product_ID ORDER BY YEAR(Order_Date)),2)AS MONEY)Product_Avg_Sales,
			CAST(ROUND(AVG(Discount_Amount) OVER (PARTITION BY Product_ID ORDER BY YEAR(Order_Date)),2)AS MONEY)Product_Avg_Discount,
			CAST(ROUND(AVG(Detailed_Net_Sales) OVER (PARTITION BY Product_ID ORDER BY YEAR(Order_Date)),2)AS MONEY)Product_Avg_N_Sales,
			CAST(ROUND(AVG(Detailed_Net_Profit) OVER (PARTITION BY Product_ID ORDER BY YEAR(Order_Date)),2)AS MONEY)Product_Avg_N_Profit,
			CAST(ROUND(AVG( Allocated_Freight) OVER (PARTITION BY Product_ID ORDER BY YEAR(Order_Date)),2)AS MONEY) Product_Avg_Freight
	FROM	Allocation

SELECT	*
FROM	Allocation_Summary
ORDER BY Product_ID,per_Year

-- Product Report per year (Totals):
CREATE OR ALTER VIEW Products_Report AS
	SELECT  CONCAT(per_Year,'-',Product_ID)Year_ID,per_Year,Product_ID, Product_Name,
			Category,SUM(Q) Q_Sold,AVG(SP) Avarage_SP,SUM(Discount_Amount) Discount,
			SUM(Detailed_Net_Sales) N_Sales,SUM(Detailed_Net_Profit) N_Profit
	FROM	Weighted_Averages
	GROUP BY per_Year,Product_ID,Product_Name,Category

SELECT	* 
FROM	Products_Report
ORDER BY Product_ID,  per_Year

-- Note : The following table was created by Python:
SELECT	*
FROM	Product_Growth

ALTER TABLE		Product_Growth
ALTER COLUMN	Product_ID INT NOT NULL

ALTER TABLE		Product_Growth
ALTER COLUMN	Product_Name NVARCHAR(40) NOT NULL

ALTER TABLE		Product_Growth
ALTER COLUMN	Category NVARCHAR(15) NOT NULL

-- Product Report per year (Totals for specific months) : 
/*
Note:
	Since the data set is incomplete(the recorded sales transactions for 1996 started in
	July-1996 and ended in May-1998) :
	1- The sales of 1997(from Jul:Dec) will be compared to the sales of 1996 (The Second Half "H2")
	2- The sales of 1997 (from Jan:Jun) will be compared to the sales of 1998 (The First Half "H1")
*/
-- Calculating Discount percentage 
	--(Total of product Discount Percentages over a specific period)
CREATE OR ALTER VIEW Discount_96 AS
	SELECT	 DISTINCT P_ID,YEAR(O_Date) per_Year, SUM( Discount) OVER (PARTITION BY P_ID ORDER BY YEAR(O_Date)) Discount_pct
	FROM	 Revnue_Transactions 
	WHERE	 YEAR (O_Date) = 1996

SELECT * 
FROM Discount_96

CREATE OR ALTER VIEW Discount_97_H1 AS
	SELECT	 DISTINCT P_ID,YEAR(O_Date) per_Year, SUM( Discount) OVER (PARTITION BY P_ID ORDER BY YEAR(O_Date)) Discount_pct
	FROM	 Revnue_Transactions 
	WHERE	 YEAR (O_Date) = 1997 AND MONTH(O_Date) <=6

SELECT * 
FROM Discount_97_H1

CREATE OR ALTER VIEW Discount_97_H2 AS
	SELECT	 DISTINCT P_ID,YEAR(O_Date) per_Year, SUM( Discount) OVER (PARTITION BY P_ID ORDER BY YEAR(O_Date)) Discount_pct
	FROM	 Revnue_Transactions 
	WHERE	 YEAR (O_Date) = 1997 AND MONTH(O_Date) >=7

SELECT * 
FROM Discount_97_H2

CREATE OR ALTER VIEW Discount_98 AS
	SELECT	 DISTINCT P_ID,YEAR(O_Date) per_Year, SUM( Discount) OVER (PARTITION BY P_ID ORDER BY YEAR(O_Date)) Discount_pct
	FROM	 Revnue_Transactions 
	WHERE	 YEAR (O_Date) = 1998

SELECT * 
FROM Discount_98

/*
Notes:
 - Q_Sold: Product's Total Quantity sold at a specific period
 - Assigned_Orders: Number of orders regarding this product at a specific period
 - SP_Order: Total of Net Sales (of a specific product) divided by the number of orders occured at a spesific period
 - SP: Average Selling price (of a specific product) at a specific period
 - Total Sales: Total Sales (before Discount) of a product for a specific period
 - Discount: Total discount (of a specific product) at a specific period
 - Discount_pct: Total of product Discount Percentages over a specific period
 - N_Sales: net Sales of a product for a specific period
 - Avg_N_Sales: Average Net Sales of a product for a specific period
 - Net_Profit: Total Profits earned of a specific product for a specific period
 - Freight: Total Freight Assigned for a specific product at a specific period
 - NS_pct: Total Net Sales per Product / Total Net Sales
 - Discount_WA:  Total Discount per Product / Total Discount
 - Deducted_Discount_pct: Total Discount per Product / Total Sales (before discount) per Product
			
*/

CREATE OR ALTER VIEW P_Sales_H2 AS
	SELECT	Year_ID+'H2' Year_ID,A.per_Year,Product_ID,Product_Name,Category,SUM(Q) Q_Sold,COUNT(Order_ID) Assigned_Orders,
			SUM(Detailed_Net_Sales)/(SELECT COUNT(DISTINCT Order_ID) FROM Allocation WHERE per_Year= 1996) SP_Order,
			AVG(SP) SP,SUM(Total_Sales) Total_Sales,SUM(Discount_Amount) Discount,
			CAST(ROUND(Discount_pct,2) AS DECIMAL(10,2)) Discount_pct,
			SUM(Discount_Amount)/(SELECT SUM(Discount_Amount) FROM Allocation WHERE per_Year= 1996) Discount_WA,
			SUM(Discount_Amount)/Sum(Total_Sales) Deducted_DIscount_pct,SUM(Detailed_Net_Sales) N_Sales, 
			SUM(Detailed_Net_Sales)/(SELECT SUM(Detailed_Net_Sales) FROM Allocation WHERE per_Year= 1996) NS_pct,
			AVG(Detailed_Net_Sales) Avg_N_Sales,SUM(Detailed_Net_Profit) Net_Profit,SUM(Allocated_Freight) Freight 
	FROM	Allocation A LEFT JOIN Discount_96 D ON A.Product_ID=D.P_ID
	WHERE	A.per_Year= 1996
	GROUP BY A.per_Year,Product_ID,Product_Name,Category,Discount_pct,Year_ID+'H2' 
	UNION
	SELECT	Year_ID+'H2' ,A.per_Year,Product_ID,Product_Name,Category,SUM(Q) ,COUNT(Order_ID) ,
			SUM(Detailed_Net_Sales)/(SELECT COUNT(DISTINCT Order_ID) FROM Allocation WHERE per_Year= 1996) ,
			AVG(SP) ,SUM(Total_Sales) ,SUM(Discount_Amount) ,CAST(ROUND(Discount_pct,2) AS DECIMAL(10,2)) ,
			SUM(Discount_Amount)/(SELECT SUM(Discount_Amount) FROM Allocation WHERE per_Year= 1996) ,
			SUM(Discount_Amount)/Sum(Total_Sales) ,SUM(Detailed_Net_Sales) , 
			SUM(Detailed_Net_Sales)/(SELECT SUM(Detailed_Net_Sales) FROM Allocation WHERE per_Year= 1996) ,
			AVG(Detailed_Net_Sales) ,SUM(Detailed_Net_Profit) ,SUM(Allocated_Freight)  
	FROM	Allocation A LEFT JOIN Discount_97_H2 D ON A.Product_ID=D.P_ID
	WHERE	A.per_Year= 1997 AND per_Month >=7
	GROUP BY A.per_Year,Product_ID,Product_Name,Category,Discount_pct,Year_ID+'H2' 

SELECT	*
FROM	P_Sales_H2
ORDER BY Product_ID, per_Year



CREATE OR ALTER VIEW P_Sales_H1 AS
	SELECT	Year_ID+'H1' Year_ID,A.per_Year,Product_ID,Product_Name,Category,SUM(Q) Q_Sold,COUNT(Order_ID) Assigned_Orders,
			SUM(Detailed_Net_Sales)/(SELECT COUNT(DISTINCT Order_ID) FROM Allocation WHERE per_Year= 1997 AND per_Month<=6) SP_Order,
			AVG(SP) SP,SUM(Total_Sales) Total_Sales,SUM(Discount_Amount) Discount,
			CAST(ROUND(Discount_pct,2) AS DECIMAL(10,2)) Discount_pct,
			SUM(Discount_Amount)/(SELECT SUM(Discount_Amount) FROM Allocation WHERE per_Year= 1997 AND per_Month<=6) Discount_WA,
			SUM(Discount_Amount)/Sum(Total_Sales) Deducted_DIscount_pct,SUM(Detailed_Net_Sales) N_Sales, 
			SUM(Detailed_Net_Sales)/(SELECT SUM(Detailed_Net_Sales) FROM Allocation WHERE per_Year= 1997 AND per_Month<=6) NS_pct,
			AVG(Detailed_Net_Sales) Avg_N_Sales,SUM(Detailed_Net_Profit) Net_Profit,SUM(Allocated_Freight) Freight 
	FROM	Allocation A LEFT JOIN Discount_97_H1 D ON A.Product_ID=D.P_ID
	WHERE	A.per_Year= 1997 AND per_Month<=6
	GROUP BY A.per_Year,Product_ID,Product_Name,Category,Discount_pct,Year_ID+'H1'
	UNION
	SELECT	Year_ID+'H1' ,A.per_Year,Product_ID,Product_Name,Category,SUM(Q) ,COUNT(Order_ID) ,
			SUM(Detailed_Net_Sales)/(SELECT COUNT(DISTINCT Order_ID) FROM Allocation WHERE per_Year= 1998) ,
			AVG(SP) ,SUM(Total_Sales) ,SUM(Discount_Amount) ,CAST(ROUND(Discount_pct,2) AS DECIMAL(10,2)) ,
			SUM(Discount_Amount)/(SELECT SUM(Discount_Amount) FROM Allocation WHERE per_Year= 1998) ,
			SUM(Discount_Amount)/Sum(Total_Sales) ,SUM(Detailed_Net_Sales) , 
			SUM(Detailed_Net_Sales)/(SELECT SUM(Detailed_Net_Sales) FROM Allocation WHERE per_Year= 1998) ,
			AVG(Detailed_Net_Sales) ,SUM(Detailed_Net_Profit) ,SUM(Allocated_Freight) 		
	FROM	Allocation A LEFT JOIN Discount_98 D ON A.Product_ID=D.P_ID
	WHERE	A.per_Year= 1998
	GROUP BY A.per_Year,Product_ID,Product_Name,Category,Discount_pct,Year_ID+'H1'

SELECT	*
FROM	P_Sales_H1
ORDER BY Product_ID,per_Year
	
-- Note : The following table was created by Python:
SELECT	*
FROM	Actual_Product_Growth

ALTER TABLE Actual_Product_Growth
ALTER COLUMN Product_ID INT NOT NULL

ALTER TABLE Actual_Product_Growth
ALTER COLUMN Product_Name NVARCHAR(40) NOT NULL

ALTER TABLE Actual_Product_Growth
ALTER COLUMN Category NVARCHAR(15) NOT NULL	


-- Product YOY Analysis
SELECT	*
FROM	Product_Growth
WHERE Product_ID = 1 OR Product_ID = 5

SELECT	*
FROM	Actual_Product_Growth
WHERE Product_ID = 1 OR Product_ID = 5
/*
 - Conclusion:
	1- Product Growth Table:
		- Whole Year 1997 vs. Half-Year 1996 and Half-Year 1998
		- The comparison might be skewed due to comparing a full year (1997) with only half-years (1996 and 1998),
		  This can lead to inaccurate growth rate calculations,
	2- Actual Product Growth Table:
		- 1st Half of 1997 vs. 1st Half of 1998 and 2nd Half of 1996 vs. 2nd Half of 1997
		- More Accurate as this comparison aligns the periods more closely by comparing similar halves, 
		  which provides a clearer picture of growth.
		- Comparing like-for-like periods (half-years) makes the growth rate more consistent 
		  and reliable in reflecting actual performance changes.
 - Result:
	The values of "Actual Product Growth" table are more accurate in measuring growth consistently 
	across equivalent periods. 
*/

--Category Performance:
/*
 Note:
	- NS_pct: "Net Sales Percentage" calculated by dividing the net sales/ category at a specific year
			  by the overall total net sales of this year.
*/
CREATE OR ALTER VIEW Category_Performance AS
	SELECT	per_Year,Category_ID,Category,SUM(Q_Sold)Category_Q_Sales,
			SUM(P_Sales) Category_Sales,SUM(P_Discount)Category_Discount, 
			SUM(P_Net_Sales) Category_N_Sales,SUM(P_Net_Profit) Category_Net_Profit,
			CASE
			WHEN per_Year=1996 THEN SUM(P_Net_Sales)/(SELECT SUM(P_Net_Sales)FROM Product_Details WHERE per_Year=1996)
			WHEN per_Year=1997 THEN SUM(P_Net_Sales)/(SELECT SUM(P_Net_Sales)FROM Product_Details WHERE per_Year=1997)
			ELSE SUM(P_Net_Sales)/(SELECT SUM(P_Net_Sales)FROM Product_Details WHERE per_Year=1998)
			END AS NS_pct
	FROM	Product_Details
	GROUP BY	per_Year,Category_ID,Category

SELECT	*
FROM	Category_Performance
ORDER BY	Category_ID,per_Year

				---------------------------------------------------------

-- 4- Employee Report:

-- Net Sales & Profit per Employee:

CREATE OR ALTER VIEW Employee_Transactions AS
	SELECT  CAST(YEAR(O_Date)AS NVARCHAR(5))+'-'+CAST(E_ID AS NVARCHAR(5))+'E' Year_ID,
			YEAR(O_Date) per_Year,E_ID Emp_ID, CONCAT(TitleOfCourtesy, ' ',LEFT(FirstName,1), '. ', LastName) Full_Name, 
			E.Country E_Country,ReportsTo,COUNT( DISTINCT O_ID) Orders_Made, SUM(Q) Q_Sold, 
			SUM(Total_Sales) Sales_Acheived, SUM(Discount_Amount) Discount_Made,
			SUM(Detailed_Net_Sales) Net_Sales_Achieved, SUM(Detailed_Net_Profit) Net_Profit_Achieved,
			CASE
			WHEN ReportsTo IS NULL THEN 'Manager'
			WHEN  E_ID  IN (SELECT DISTINCT ReportsTo FROM Employees) THEN 'Supervisor'
			ELSE 'Employee'
			END AS Position
	FROM    Revnue_Transactions RT LEFT JOIN Employees E ON RT.E_ID = E.EmployeeID
									
	GROUP BY	YEAR(O_Date),E_ID, ReportsTo,Title, CONCAT(TitleOfCourtesy, ' ',LEFT(FirstName,1), '. ', LastName) ,E.Country
			

SELECT	*
FROM	Employee_Transactions

CREATE OR ALTER VIEW Employee_performance AS
	SELECT	CAST(YEAR(O_Date)AS NVARCHAR(5))+CAST(MONTH(O_Date)AS NVARCHAR(5))+'-'+CAST(E_ID AS NVARCHAR(5))+'E' Year_ID,
			YEAR(O_Date)per_Year,MONTH(O_Date)per_Month,E_ID,
			CONCAT(TitleOfCourtesy, ' ',LEFT(FirstName,1), '. ', LastName) Full_Name,
			COUNT(O_ID) Orders_Made,
			SUM(O_Total_Sales) Sales_Acheived,SUM(O_Discount_Amount)Discount_Made,
			SUM(O_Net_Sales)Net_Sales_Achieved,SUM(O_Net_Profit)Net_Profit_Achieved,
			CASE
			WHEN Shipping_Status LIKE 'Shipped' THEN COUNT(Shipping_Status) 
			END AS Delivered_Orders,
			CASE
			WHEN Shipping_Status LIKE '%Transi%'THEN COUNT(Shipping_Status) 
			END AS Delayed_Orders
	FROM	Order_Transactions OT  JOIN Employees E
			ON OT.E_ID = E.EmployeeID
	GROUP BY	FirstName,YEAR(O_Date),MONTH(O_Date),E_ID, Shipping_Status,
				CONCAT(TitleOfCourtesy, ' ',LEFT(FirstName,1), '. ', LastName) 		

SELECT	*
FROM	Employee_performance

					---------------------------------------------------------

-- 5- Shippers Report:
CREATE OR ALTER VIEW Shipping_Report AS	
	SELECT	YEAR(O_Date) per_Year,O_Date ODate,Required_Date,Shipped_Date,O_ID,Days_to_Ship,
			O_Date,C_ID,Country,E_ID,O_Net_Sales,sum(Quantity_Sold) Q_Shipped,
			Freight,S.CompanyName Shipping_Company,Shipping_Status,
			CASE 
			WHEN Shipped_Date <= Required_Date AND Shipping_Status LIKE 'Shipped' THEN 1
			ELSE 0
			END AS Delivery_Status
	FROM	Order_Transactions OT LEFT JOIN Shippers S ON OT.ShipVia=S.ShipperID
								  LEFT JOIN Customers C ON OT.C_ID=C.CustomerID
	GROUP BY YEAR(O_Date),O_Date ,Required_Date,Shipped_Date,O_ID,Days_to_Ship, O_Date,C_ID,Country,
			 E_ID,O_Net_Sales,Freight,S.CompanyName ,Shipping_Status
	
SELECT	*
FROM	Shipping_Report

/*
Note:
	Since the data set is incomplete(the recorded sales transactions for 1996 started in
	July-1996 and ended in May-1998) :
	1- The Sales & Shipping Cost of 1997(from Jul:Dec) will be compared to the Sales & 
		Shipping Cost of 1996 (The Second Half "H2")
	2- The Sales & Shipping Cost of 1997 (from Jan:Jun) will be compared to the Sales &
		Shipping Cost of 1998 (The First Half "H1")
*/
CREATE OR ALTER VIEW Shipping_Report_H2 AS
	SELECT	CAST(YEAR(ODate)AS NVARCHAR(5))+'H2-'+ LEFT(Shipping_Company,1) Year_ID,
			YEAR(ODate) per_Year,Shipping_Company,COUNT(O_ID) Handeled_Orders, SUM(O_Net_Sales) Net_Sales_of_Shipped,
			SUM(Freight) Shipping_Cost,CAST(ROUND(AVG(Days_to_Ship),2)AS DECIMAL(10,2)) Avg_Days_to_Ship,
			SUM(Freight)/((SELECT SUM(Freight) FROM Shipping_Report WHERE YEAR(ODate) = 1996)) Shipping_Cost_WA,
			CAST(ROUND(SUM(Delivery_Status)/CAST(ROUND(COUNT(O_ID),2)AS DECIMAL(10,2)),4) AS DECIMAL(10,4)) On_Time_Delivery_pct,
			SUM(Freight)/COUNT(O_ID) Avg_Freight_per_Order
	FROM	Shipping_Report
	WHERE	YEAR(ODate)=1996
	GROUP BY YEAR(ODate),Shipping_Company
	UNION
	SELECT	CAST(YEAR(ODate)AS NVARCHAR(5))+'H2-'+ LEFT(Shipping_Company,1),
			YEAR(ODate) ,Shipping_Company,COUNT(O_ID) , SUM(O_Net_Sales) ,SUM(Freight) ,
			CAST(ROUND(AVG(Days_to_Ship),2)AS DECIMAL(10,2)) ,
			SUM(Freight)/(SELECT SUM(Freight) FROM Shipping_Report WHERE YEAR(ODate) = 1997 AND MONTH(ODate) >=7) ,
			CAST(ROUND(SUM(Delivery_Status)/CAST(ROUND(COUNT(O_ID),2)AS DECIMAL(10,2)),4) AS DECIMAL(10,4)) ,
			SUM(Freight)/COUNT(O_ID) Avg_Freight_per_Order
	FROM	Shipping_Report
	WHERE	YEAR(ODate)=1997 AND MONTH(ODate) >=7
	GROUP BY YEAR(ODate),Shipping_Company

SELECT	*	
FROM	Shipping_Report_H2

CREATE OR ALTER VIEW Shipping_Report_H1 AS
	SELECT	CAST(YEAR(ODate)AS NVARCHAR(5))+'H1-'+ LEFT(Shipping_Company,1) Year_ID,
			YEAR(ODate) per_Year,Shipping_Company,COUNT(O_ID) Handeled_Orders, SUM(O_Net_Sales) Net_Sales_of_Shipped,
			SUM(Freight) Shipping_Cost,CAST(ROUND(AVG(Days_to_Ship),2)AS DECIMAL(10,2)) Avg_Days_to_Ship,
			SUM(Freight)/((SELECT SUM(Freight) FROM Shipping_Report WHERE YEAR(ODate) = 1997 AND MONTH(ODate) <=6)) Shipping_Cost_WA,
			CAST(ROUND(SUM(Delivery_Status)/CAST(ROUND(COUNT(O_ID),2)AS DECIMAL(10,2)),4) AS DECIMAL(10,4)) On_Time_Delivery_pct,
			SUM(Freight)/COUNT(O_ID) Avg_Freight_per_Order
	FROM	Shipping_Report
	WHERE	YEAR(ODate)=1997 AND MONTH(ODate) <=6
	GROUP BY YEAR(ODate),Shipping_Company
	UNION
	SELECT	CAST(YEAR(ODate)AS NVARCHAR(5))+'H1-'+ LEFT(Shipping_Company,1),
			YEAR(ODate) ,Shipping_Company,COUNT(O_ID) , SUM(O_Net_Sales) ,SUM(Freight) ,
			CAST(ROUND(AVG(Days_to_Ship),2)AS DECIMAL(10,2)) ,
			SUM(Freight)/(SELECT SUM(Freight) FROM Shipping_Report WHERE YEAR(ODate) = 1998) ,
			CAST(ROUND(SUM(Delivery_Status)/CAST(ROUND(COUNT(O_ID),2)AS DECIMAL(10,2)),4) AS DECIMAL(10,4)) ,
			SUM(Freight)/COUNT(O_ID) Avg_Freight_per_Order
	FROM	Shipping_Report
	WHERE	YEAR(ODate)=1998
	GROUP BY YEAR(ODate),Shipping_Company

SELECT	*
FROM	Shipping_Report_H1







	

