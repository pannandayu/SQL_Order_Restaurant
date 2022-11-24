-- All Merge (Orders, Menu, Promotion)
select *
from orders o 
left join menu m 
on o.menu_id = m.menu_id 
and m.effective_date =
		(
	     select max(effective_date) from menu m2
	     where m2.menu_id = o.menu_id and m2.effective_date <= o.sales_date
	    )
left join promotion p 
on o.sales_date between p.start_date and p.end_date 
order by sales_date, order_id;

-- Data Integrity Check
select count(*) as data_count
from orders o 
left join menu m 
on o.menu_id = m.menu_id 
and m.effective_date =
		(
	     select max(effective_date) from menu m2
	     where m2.menu_id = o.menu_id and m2.effective_date  <= o.sales_date
	    )
left join promotion p 
on o.sales_date between p.start_date and p.end_date; 
-- same amount with orders data

-- Effective Date Validity Check
with effective_date
as
(
	select *
	from orders o 
	left join menu m 
	on o.menu_id = m.menu_id 
	and m.effective_date = 
			(
	          select max(effective_date) from menu m2
	          where m2.menu_id = o.menu_id and m2.effective_date  <= o.sales_date
	      	)
	left join promotion p 
	on o.sales_date between p.start_date and p.end_date 
	order by sales_date
)
select 
	sales_date, 
	effective_date
from effective_date 
where sales_date < effective_date or effective_date > sales_date; 
-- means that effective date always updated to the latest change 
-- or no effective dates precede the sales date

-- Discount Date Validity Check
with discount_date
as
(
	select 
		o.sales_date, p.start_date, p.end_date, 
		p.disc_value, p.max_disc
	from orders o 
	left join menu m 
	on o.menu_id = m.menu_id 
	and m.effective_date =
			(
		     select max(effective_date) from menu m2
		     where m2.menu_id = o.menu_id and m2.effective_date  <= o.sales_date
		    )
	left join promotion p 
	on o.sales_date between p.start_date and p.end_date
	order by sales_date
)
select *
from discount_date
where sales_date > end_date or sales_date < start_date; 
-- no discount given outside the specified date

-- Max Discount Value Validity check
with max_discount
as
(
	select 
		o.menu_id, o.quantity, o.sales_date, m.price, m.cogs, 
		m.effective_date, p.disc_value,p.max_disc, p.start_date, p.end_date, 
		(price * quantity) as revenue, (cogs * quantity) as total_cogs,
		case 
			when disc_value * (price * quantity) > max_disc then max_disc
			when disc_value * (price * quantity) is null then 0
			else disc_value * (price * quantity) 
		end as discount_price
	from orders o 
	left join menu m 
	on o.menu_id = m.menu_id 
	and m.effective_date = 
		(
			select max(effective_date) from menu m2
			where m2.menu_id = o.menu_id and m2.effective_date  <= o.sales_date
		)
	left join promotion p 
	on o.sales_date between p.start_date and p.end_date 
	order by sales_date, order_id 
)
select 
	max_disc, 
	discount_price
from max_discount
where end_date is not null and discount_price > max_disc;
-- no discount price exceed the maximum discount value


-- Following the Specified Formula / Definition
-- 1. Revenue: Total Sales (Item Price * Qty)
-- 2. Gross Profit: Total Sales (Revenue) - Total COGS (COGS * Qty)

-- Revenue and Gross Profit Daily
with revenue_grossprofit_daily
as
(
	select 
			o.order_id, o.menu_id, o.quantity, 
			m.price, m.cogs, o.sales_date,m.effective_date
	from orders o 
	left join menu m 
	on o.menu_id = m.menu_id 
	and m.effective_date = 
		(
			select max(effective_date) from menu m2
			where m2.menu_id = o.menu_id and m2.effective_date  <= o.sales_date
		)
	left join promotion p 
	on o.sales_date between p.start_date and p.end_date 
	order by sales_date, order_id
)
select
	sales_date, 
	sum(price * quantity) as revenue,
	sum((price * quantity) - (cogs * quantity)) as gross_profit
from revenue_grossprofit_daily
group by 1
order by 1;

-- Revenue and Gross Profit Weekly
with revenue_grossprofit_weekly
as
(
	select 
			o.order_id, o.menu_id, o.quantity, 
			m.price, m.cogs, o.sales_date, m.effective_date
	from orders o 
	left join menu m 
	on o.menu_id = m.menu_id 
	and m.effective_date = 
		(
			select max(effective_date) from menu m2
			where m2.menu_id = o.menu_id and m2.effective_date  <= o.sales_date
		)
	left join promotion p 
	on o.sales_date between p.start_date and p.end_date 
	order by sales_date, order_id
)
select 
	case 
		when extract(week from sales_date) > 50 then extract(week from sales_date) - 52
		else extract(week from sales_date) + 1
	end as week,
	sum(price * quantity) as revenue,
	sum((price * quantity) - (cogs * quantity)) as gross_profit
from revenue_grossprofit_weekly
group by 1
order by 1;

-- Revenue and Gross Profit Monthly
with revenue_grossprofit_monthly
as
(
	select 
			o.order_id, o.menu_id, o.quantity, 
			m.price, m.cogs, o.sales_date, m.effective_date
	from orders o 
	left join menu m 
	on o.menu_id = m.menu_id 
	and m.effective_date = 
		(
			select max(effective_date) from menu m2
			where m2.menu_id = o.menu_id and m2.effective_date  <= o.sales_date
		)
	left join promotion p 
	on o.sales_date between p.start_date and p.end_date 
	order by sales_date, order_id
)
select 
	extract(month from sales_date) as month, 
	sum(price * quantity) as revenue, 
	sum((price * quantity) - (cogs * quantity)) as gross_profit, 
	round(sum((price * quantity) - (cogs * quantity)) / sum(price * quantity * 1.0) * 100,2) as "gross_profit_margin (%)"
from revenue_grossprofit_monthly
group by 1
order by 1;

-- Net Profit and Net Profit Margin (Monthly)
-- Net Profit formula = Revenue(Item Price * Qty) - Discount Price(Discount * Revenue) - COGS(COGS * Qty)
-- Net Profit Margin formula = Net Profit / Revenue * 100
with netprofit_monthly
as
(
	select 
			o.menu_id, o.quantity, o.sales_date, 
			m.price, m.cogs, m.effective_date, p.disc_value,
			p.max_disc, p.start_date, p.end_date, 
			(price * quantity) as revenue, (cogs * quantity) as total_cogs,
			case 
				when disc_value * (price * quantity) > max_disc then max_disc
				when disc_value * (price * quantity) is null then 0
				else disc_value * (price * quantity) 
			end as discount_price
	from orders o 
	left join menu m 
	on o.menu_id = m.menu_id 
	and m.effective_date = 
		(
			select max(effective_date) from menu m2
			where m2.menu_id = o.menu_id and m2.effective_date  <= o.sales_date
		)
	left join promotion p 
	on o.sales_date between p.start_date and p.end_date 
	order by sales_date, order_id 
)
select 
	extract(month from sales_date) as month, 
	sum(revenue - total_cogs - discount_price) as net_profit, sum(revenue) as revenue,
	round(sum(revenue - total_cogs - discount_price) / sum(revenue),4) * 100 as "net_profit_margin (%)"
from netprofit_monthly
group by 1
order by 1;

-- Product Sold
select 
	o.menu_id, 
	m.brand, 
	m.name, 
	sum(quantity) as quantity_sold
from orders o 
join 
	(select 
		distinct menu_id, 
		brand, 
		name 
	from menu) as m
on o.menu_id = m.menu_id 
group by 1,2,3
order by 1;

-- Revenue, COGS, and Profit Margin by Product Sold
with revenue_cogs
as
(
	select 
		o.menu_id, o.quantity, m.brand, 
		m.name, m.price, m.cogs, 
		(price * quantity) as revenue,
		(cogs * quantity) as total_cogs
	from orders o
	left join menu m 
	on o.menu_id = m.menu_id 
	and m.effective_date =
			(
			 select max(effective_date) from menu m2
			 where m2.menu_id = o.menu_id and m2.effective_date  <= o.sales_date
			)
	left join promotion p 
	on o.sales_date between p.start_date and p.end_date
)
select menu_id, brand, name, sum(revenue) as revenue, sum(total_cogs) as total_cogs,
	round(sum(revenue - total_cogs) / sum(revenue * 1.0) * 100,2) as "profit_margin (%)"
from revenue_cogs
group by 1,2,3
order by 1;

-- Profit Margin Change by Each Product Production
with margin
as
(
	select 
		*, 
		price - cogs as margin
	from menu m 
	order by 1,6
)
select 
	distinct max(effective_date) as effective_date, 
	menu_id, brand, name, max(margin) - min(margin) as change,
	round((max(margin) - min(margin)) / (min(margin) * 1.0) * 100,2) as "profit_margin_change (%)"
from margin
group by 2,3,4
order by 2;

-- Discount and COGS Contribution to Revenue
with discount_cogs
as
(
	select 
		o.menu_id, o.quantity, o.sales_date, 
		m.price, m.cogs, m.effective_date, 
		p.disc_value,p.max_disc, p.start_date, p.end_date, 
		(price * quantity) as revenue, (cogs * quantity) as total_cogs,
	case 
		when disc_value * (price * quantity) > max_disc then max_disc
		when disc_value * (price * quantity) is null then 0
		else disc_value * (price * quantity) 
	end as discount_price
	from orders o 
	left join menu m 
	on o.menu_id = m.menu_id 
	and m.effective_date = 
		(
			select max(effective_date) from menu m2
			where m2.menu_id = o.menu_id and m2.effective_date  <= o.sales_date
		)
	left join promotion p 
	on o.sales_date between p.start_date and p.end_date 
	order by sales_date, order_id 
)
select sum(revenue) as revenue, 
round(sum(discount_price) / sum(revenue) * 100,2) as "discount_contribution (%)",
round(sum(total_cogs) / sum(revenue * 1.0) * 100,2) as "cogs_contribution (%)"
from discount_cogs;