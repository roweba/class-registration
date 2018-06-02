import psycopg2, sys

def print_row(term, course_code, course_name, instructor_name, total_enrollment, maximum_capacity):
	print("%6s %10s %-35s %-25s %s/%s"%(str(term), str(course_code), str(course_name), str(instructor_name), str(total_enrollment), str(maximum_capacity)) )

#open db connection
psql_user = '' #Change this to your username
psql_db = '' #Change this to your personal DB name
psql_password = '' #Put your password (as a string) here
psql_server = '' #Put the server name here
psql_port = #Put the port (as an int) here

conn = psycopg2.connect(dbname=psql_db,user=psql_user,password=psql_password,host=psql_server,port=psql_port)
cursor = conn.cursor()

cursor.execute("select course_offerings.term, course_offerings.course_code, course_offerings.name, course_offerings.instructor, count(enrollment.student_id), course_offerings.capacity from course_offerings left join enrollment on course_offerings.term = enrollment.term and course_offerings.course_code = enrollment.course_code group by course_offerings.term, course_offerings.course_code, course_offerings.name, course_offerings.instructor order by course_offerings.term asc, course_offerings.name asc;")
for row in cursor:
	term, course_code, course_name, instructor, count, capacity = row[0:6]
	print_row(term, course_code, course_name, instructor, count, capacity)

conn.commit()
cursor.close()
conn.close()
