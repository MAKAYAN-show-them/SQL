### 1. Monthly Appointment Volume and Growth per Doctor
use hospital_management_database;
SELECT * FROM doctors;

SELECT * , month(appointment_date) as month
FROM appointments
ORDER BY doctor_id , month;

WITH appointments_new as (SELECT * , month(appointment_date) as month
FROM appointments WHERE status != 'Cancelled' ORDER BY doctor_id),
Appointments_Months_each_doctor as (SELECT doctor_id , 
SUM(CASE WHEN month = 1 THEN  1 ELSE 0 END) as Jan,
SUM(CASE WHEN month = 2 THEN  1 ELSE 0 END) as Feb, 
SUM(CASE WHEN month = 3 THEN  1 ELSE 0 END) as Mar,
SUM(CASE WHEN month = 4 THEN  1 ELSE 0 END) as Apr,
SUM(CASE WHEN month = 5 THEN  1 ELSE 0 END) as May,
SUM(CASE WHEN month = 6 THEN  1 ELSE 0 END) as Jun, 
SUM(CASE WHEN month = 7 THEN  1 ELSE 0 END) as Jul,
SUM(CASE WHEN month = 8 THEN  1 ELSE 0 END) as Aug,
SUM(CASE WHEN month = 9 THEN  1 ELSE 0 END) as Sep,
SUM(CASE WHEN month = 10 THEN  1 ELSE 0 END) as Oct, 
SUM(CASE WHEN month = 11 THEN  1 ELSE 0 END) as Nov,
SUM(CASE WHEN month = 12 THEN  1 ELSE 0 END) as `Dec`
FROM appointments_new GROUP BY doctor_id ORDER BY doctor_id)
SELECT doctor_id,
       Jan,
       Feb,
       (Feb - Jan) AS `Growth_from_Jan_Feb`,
       Mar,
       (Mar - Feb) AS `Growth_from_Feb_Mar`,
       Apr,
       (Apr - Mar) AS `Growth_from_Mar_Apr`,
       May,
       (May - Apr) AS `Growth_from_Apr_May`,
       Jun,
       (Jun - May) AS `Growth_from_May_Jun`,
       Jul,
       (Jul - Jun) AS `Growth_from_Jun_Jul`,
       Aug,
       (Aug - Jul) AS `Growth_from_Jul_Aug`,
       Sep,
       (Sep - Aug) AS `Growth_from_Aug_Sep`,
       Oct,
       (Oct - Sep) AS `Growth_from_Sep_Oct`
FROM Appointments_Months_each_doctor;

# 2. Total Revenue per Doctor

SELECT concat(first_name ,' ', last_name ) as Doctor_name ,specialization, ROUND(SUM(COST),2) as Revenue_generated FROM doctors
JOIN appointments ON 
appointments.doctor_id = doctors.doctor_id
JOIN treatments ON
treatments.appointment_id = appointments.appointment_id
group by Doctor_name , specialization
Order by Revenue_generated  Desc;


-- 🧾 3. Insurance vs Non-Insurance Billing Comparison
-- Question:
-- Find the total billed amount and count of treatments where the payment method was Insurance vs. Non-Insurance (Cash or Card). Show percentages of each.

SELECT 'Insurance' as `Payment Method` , count(billing.treatment_id) as `Total treatment` , 
sum(amount) as `Total Amount`, (Round((sum(amount)/@Total_revenue)*100,2)) as `Percentage of Total Amount`  
FROM treatments 
JOIN billing
ON billing.treatment_id = treatments.treatment_id
where payment_method = 'Insurance'  and payment_status = 'Paid'

UNION

SELECT 'Others(Card or Cash)' as `Payment Method` , count(billing.treatment_id) as `Total treatment` , 
sum(amount) as `Total Amount`, (Round((sum(amount)/@Total_revenue)*100,2)) as `Percentage of Total Amount`  
FROM treatments 
JOIN billing
ON billing.treatment_id = treatments.treatment_id
where (payment_method = 'Cash' or payment_method = 'Card') and payment_status = 'Paid';

SELECT * FROM treatments 
JOIN billing
ON billing.treatment_id = treatments.treatment_id;

-- 🧑‍⚕️ 4. Top 5 Doctors with Most Expensive Treatments
-- Question:
-- Identify the top 5 doctors who administered the most expensive average treatment cost. Include their full name, specialization, and average treatment cost.
Use hospital_management_database;
select doctors.doctor_id ,concat(first_name,' ', last_name)  as doctor_name, specialization ,round(avg(cost),2) as `Average Treatment cost` from doctors
JOIN appointments
ON doctors.doctor_id = appointments.doctor_id
JOIN treatments 
ON treatments.appointment_id = appointments.appointment_id
group by doctor_id ,doctor_name,specialization
Order by `Average Treatment cost` desc
LIMIT 5;

-- ⏰ 5. Missed Appointments Pattern
-- Question:
-- Find patients who have had more than 2 Cancelled appointments. List their name, contact, number of cancellations, and total scheduled appointments.

with cancel_appointments as (SELECT patient_id , count(appointment_id) as `number of cancellations` From appointments where status = 'Cancelled'
GROUP BY patient_id 
having `number of cancellations` > 2),
count_patients_appointments as (SELECT patient_id , count(appointment_id) as `total scheduled appointments` FROM appointments group by patient_id) 
SELECT concat(first_name,' ', last_name) as `patient_name` , contact_number , `number of cancellations` , `total scheduled appointments` FROM cancel_appointments 
LEFT JOIN patients ON patients.patient_id = cancel_appointments.patient_id
LEFT JOIN count_patients_appointments ON count_patients_appointments.patient_id = cancel_appointments.patient_id;

-- 🗓️ 6. First and Last Visit per Patient
-- Question:
-- For each patient, return their first and last appointment date, and how many days have passed between them.


with first_appointment as (Select patient_id , min(appointment_date) as first_appointment_date from appointments group by patient_id),
last_appointment as (Select patient_id , max(appointment_date) as last_appointment_date from appointments group by patient_id)
SELECT last_appointment.patient_id,concat(first_name,' ',last_name) as name, first_appointment_date,last_appointment_date ,datediff(last_appointment_date,first_appointment_date)  as first_last_day_difference
from last_appointment JOIN first_appointment ON last_appointment.patient_id = first_appointment.patient_id
JOIN patients ON
patients.patient_id = last_appointment.patient_id
WHERE first_appointment_date != last_appointment_date
ORDER BY first_last_day_difference desc;

-- 💳 7. Pending Payments Older Than 30 Days
-- Question:
-- List all bills where the payment status is 'Pending' and the bill_date is more than 30 days before today. Include patient name, bill amount, treatment date, and contact info.

SELECT concat(first_name," ",last_name) as patient_name, amount as bill_amount, `treatments`.`treatment_date`,`patients`.`contact_number` FROM (SELECT * , datediff((now()),bill_date)  as bill_date_greater_30 FROM billing  billing where payment_status = 'pending') as a
JOIN patients ON patients.patient_id = a.patient_id
JOIN appointments ON appointments.patient_id = a.patient_id
JOIN treatments ON treatments.appointment_id = appointments.appointment_id
WHERE bill_date_greater_30 > 30
ORDER BY bill_amount DESC;

-- 🧪 8. Most Common Treatments per Specialization
-- Question:
-- For each doctor specialization, find the most commonly administered treatment_type, and the number of times it was performed.

with top_treatment as (select * ,RANK() over (partition by specialization order by times_treatment_performed desc) as Rank_1 FROM (SELECT `doctors`.`specialization`,`treatments`.`treatment_type` , count(`treatments`.`treatment_id`) as times_treatment_performed FROM treatments JOIN appointments 
ON appointments.appointment_id = treatments.appointment_id
JOIN doctors ON appointments.doctor_id = doctors.doctor_id
GROUP BY `doctors`.`specialization`,`treatments`.`treatment_type`) as a)
SELECT specialization , treatment_type, times_treatment_performed FROM top_treatment where Rank_1 = 1;

-- 🏥 9. Branch-wise Doctor Load
-- Question:
-- Calculate the average number of appointments per doctor per branch. Include the branch, doctor count, total appointments, and average appointments per doctor.

with doctor_count as (SELECT hospital_branch , count(doctor_id) as doctor_count FROM doctors GROUP BY hospital_branch),
total_appointments as (SELECT hospital_branch , count(appointment_id) as total_appointments FROM appointments  JOIN doctors ON doctors.doctor_id = appointments.doctor_id 
GROUP BY hospital_branch)
SELECT dc.hospital_branch , doctor_count,total_appointments , round((total_appointments/doctor_count),2) as average_appointment_per_doctor  FROM doctor_count as dc
JOIN total_appointments as ta
ON ta.hospital_branch = dc.hospital_branch;


-- 📊 10. Patient Lifetime Value (LTV)
-- Question:
-- Calculate the lifetime value for each patient defined as the total amount billed over all their visits. Show patient ID, name, total number of treatments, and total amount billed.

sELECT p.patient_id, concat(first_name,' ', last_name) as patient_name, count(t.treatment_id) as total_number_of_treatments , sum(amount) as total_amount_billed FROM patients p
JOIN appointments a ON a.patient_id = p.patient_id
JOIN treatments t ON t.appointment_id = a.appointment_id
JOIN billing b ON b.treatment_id = t.treatment_id 
GROUP BY p.patient_id , patient_name
order by total_amount_billed DESC , total_number_of_treatments DESC;



