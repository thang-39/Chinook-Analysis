USE Chinook;


-- Q3. Which Genres sell the most tracks in the USA? Suggest 3 artists whose albums the store should purchase
 -- 3.1 Which genres sell the most tracks in the USA
SELECT genre.Name AS genre, SUM(invoiceline.Quantity) AS total_sold
  FROM genre
  JOIN track ON genre.Genreid = track.Genreid
  JOIN invoiceline ON track.TrackId = invoiceline.TrackId
  JOIN invoice ON invoiceline.InvoiceId = invoice.InvoiceId
 WHERE invoice.BillingCountry = 'USA'
 GROUP BY genre.GenreId
 ORDER BY total_sold DESC
 LIMIT 8;
-- 3.2 Recommendation for the three artists whose albums we should purchase for the store
SELECT artist.Name AS Artist,
	   SUM(invoiceline.Quantity) AS Total_sold
  FROM artist
  JOIN album 
    ON artist.ArtistId = album.ArtistId
  JOIN track 
    ON album.AlbumId = track.AlbumId
  JOIN genre 
    ON genre.GenreId = track.GenreId
  JOIN invoiceline 
    ON track.TrackId = invoiceline.TrackId
  JOIN invoice 
    ON invoiceline.InvoiceId = invoice.InvoiceId
 WHERE invoice.BillingCountry = 'USA' AND genre.name = 'Rock'
 GROUP BY artist.Name
 ORDER BY total_sold DESC
 LIMIT 3;



-- Q4. Analyzing Sales Agent performance
SELECT e.EmployeeId,
	   CONCAT(e.firstname, ' ',  e.lastname) AS Sales_agent_name,
	   e.HireDate,
       COUNT(*) AS Number_of_sales,
       (SELECT COUNT(DISTINCT c.customerid)
		  FROM customer
		 GROUP BY employeeid) AS Number_of_customers,
       SUM(i.total) AS Total_revenue,
       ROUND(CAST(SUM(i.total) AS FLOAT) / CAST(COUNT(c.customerid) AS FLOAT), 2) AS Revenue_per_customer
  FROM employee e
  JOIN customer c
    ON e.employeeid = c.supportrepid
  JOIN invoice i
    ON c.customerid = i.customerid
 GROUP BY employeeid
 ORDER BY Total_revenue;
 

-- Q5. Analying Sales by Country
WITH country_stat AS (
						SELECT Country,
							   COUNT(DISTINCT c.customerid) AS Number_of_customers,
                               SUM(i.Total) AS Value_of_sales,
                               COUNT(DISTINCT i.invoiceid) AS Number_of_orders,
                               CASE
									WHEN COUNT(DISTINCT c.customerid) = 1 THEN 'Other'
                                    ELSE Country
							   END AS Country_sort
                          FROM customer c
                          JOIN invoice i
                            ON c.customerid = i.customerid
						 GROUP BY country
					)
SELECT Country_sort,
	   SUM(Number_of_customers) AS Total_number_of_customers,
       SUM(Value_of_sales) AS Total_value_of_sales,
       ROUND(SUM(Value_of_sales) / SUM(Number_of_customers), 2) AS AVG_value_of_sales_per_customer,
       ROUND(SUM(Value_of_sales) / SUM(Number_of_orders), 2) AS AVG_order_value 
  FROM Country_stat
 GROUP BY Country_sort
 ORDER BY Total_value_of_sales DESC;
 

-- Q6. Albums vs. Individual tracks --> Percentage of purchases of individual tracks vs whole albums
SELECT 
    SUM(CASE 
            WHEN album_track_count = invoice_track_count 
            AND invoice_track_count > 1 
            THEN 1 
            ELSE 0 
        END) AS whole_albums_count,
    SUM(CASE 
            WHEN album_track_count <> invoice_track_count 
            OR invoice_track_count = 1 
            THEN 1 
            ELSE 0 
        END) AS individual_tracks_count,
    COUNT(*) AS total_invoices_count,
    (SUM(CASE 
            WHEN album_track_count = invoice_track_count 
            AND invoice_track_count > 1 
            THEN 1 
            ELSE 0 
        END) / COUNT(*)) * 100 AS whole_albums_percentage,
    (SUM(CASE 
            WHEN album_track_count <> invoice_track_count 
            OR invoice_track_count = 1 
            THEN 1 
            ELSE 0 
         END) / COUNT(*)) * 100 AS individual_tracks_percentage
FROM (
    SELECT 
        i.invoiceid,
        t.albumid,
        COUNT(DISTINCT t.trackid) AS invoice_track_count,
        (
            SELECT COUNT(*) 
            FROM track t2 
            WHERE t2.albumid = t.albumid
        ) AS album_track_count
    FROM invoice i
    JOIN invoiceline ii ON i.invoiceid = ii.invoiceid
    JOIN track t ON ii.trackid = t.trackid
   GROUP BY i.invoiceid, t.albumid
) AS invoice_album_track_counts;


-- Q7. Which artist is used in the most playlists?
SELECT ar.Name, COUNT(DISTINCT pt.playlistid) AS Playlist_count
  FROM playlisttrack pt
  JOIN track t 
    ON pt.trackid = t.trackid
  JOIN album al 
    ON t.albumid = al.albumid
  JOIN artist ar 
    ON al.artistid = ar.artistid
 GROUP BY ar.Name
 ORDER BY Playlist_count DESC
 LIMIT 1;
 

-- Q8. How many tracks have been purchased vs. not purchased?
WITH Sort_purchased AS (
						 SELECT TrackId, Name,
								CASE 
									WHEN EXISTS (SELECT trackid
												   FROM invoiceline il
												  WHERE t.trackid = il.trackid) THEN 'Purchased'
									ELSE 'Not purchased'
								END AS 'Purchased_or_not'
						   FROM track t
						  GROUP BY trackid
						)
SELECT Purchased_or_not,
	   COUNT(trackid) AS Number_of_tracks,
       ROUND(100* CAST(COUNT(trackid) AS FLOAT) / (SELECT COUNT(*)
													 FROM track), 2) AS Percent
  FROM Sort_purchased
 GROUP BY Purchased_or_not;
 
 
-- Q9. Is the range of tracks in the store reflective of their sales popularity?

-- SELECT g.GenreId, g.Name,
-- 	   COUNT(t.trackid) AS Total_tracks_instore,
--        ROUND(CAST(COUNT(t.trackid) AS FLOAT) / (SELECT COUNT(*)
-- 												  FROM track) * 100, 2) AS Instore_tracks_share,
-- 	   COUNT(il.trackid) AS Total_tracks_sold,
-- 	   ROUND(CAST(COUNT(il.trackid) AS FLOAT) / (SELECT COUNT(*)
-- 												   FROM invoiceline) * 100, 2) AS Sold_tracks_share
--   FROM genre g
--   LEFT JOIN track t
--     ON g.GenreId = t.GenreId
--   LEFT JOIN invoiceline il
--     ON t.TrackId = il.TrackId
--   GROUP BY GenreId
--   ORDER BY Sold_tracks_share DESC;
  
  WITH 
	-- CTE 1
	Total_tracks_instore AS (

	SELECT g.GenreId, g.Name,
		   COUNT(t.trackid) AS Total_tracks_instore
	  FROM genre g 
	  JOIN track t ON g.GenreId = t.GenreId
	 GROUP BY GenreId),
    -- CTE 2
	Total_tracks_sold AS (
	  SELECT g.GenreId, g.Name,
			 COUNT(DISTINCT il.trackid) AS Total_tracks_sold
		FROM genre g 
		LEFT JOIN track t ON g.GenreId = t.GenreId
		JOIN invoiceline il ON t.TrackId = il.TrackId
	   GROUP BY GenreId)

SELECT i.GenreId, i.Name,
	   i.Total_tracks_instore,
       (CASE
            WHEN s.Total_tracks_sold > 0 THEN s.Total_tracks_sold
            ELSE 0
       END) AS Total_tracks_sold,
       (CASE
            WHEN s.Total_tracks_sold != 0 THEN ROUND((Total_tracks_sold /i.Total_tracks_instore * 100),2)
            ELSE 0 / i.Total_tracks_instore * 100
       END) AS Proportion_tracks_sold
  FROM Total_tracks_instore i
  LEFT JOIN Total_tracks_sold s ON i.GenreId = s.GenreId
 GROUP BY i.GenreId
 ORDER BY Total_tracks_sold DESC;
  

-- Q10. Do protected vs. non-protected media types have an effect on popularity?
SELECT CASE
			WHEN mt.Name LIKE '%protect%' THEN 'Protected'
            ELSE 'Non protected'
            END AS Mediatype_sort,
	   COUNT(il.trackid) AS Total_tracks_sold,
	   ROUND(CAST(COUNT(il.trackid) AS FLOAT) / (SELECT COUNT(*)
												   FROM invoiceline) * 100, 2) AS Sold_tracks_share
  FROM mediatype mt
  LEFT JOIN track t
    ON mt.MediaTypeId = t.MediaTypeId
  LEFT JOIN invoiceline il
    ON t.TrackId = il.TrackId
 GROUP BY Mediatype_sort
 ORDER BY Sold_tracks_share;