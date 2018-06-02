import psycopg2, sys

def print_header(student_id, student_name):
	print("Transcript for %s (%s)"%(str(student_id), str(student_name)) )

def print_row(course_term, course_code, course_name, grade):
	if grade is not None:
		print("%6s %10s %-35s   GRADE: %s"%(str(course_term), str(course_code), str(course_name), str(grade)) )
	else:
		print("%6s %10s %-35s   (NO GRADE ASSIGNED)"%(str(course_term), str(course_code), str(course_name)) )

if len(sys.argv) < 2:
	print('Usage: %s <student id>'%sys.argv[0], file=sys.stderr)
	sys.exit(0)

student_id = sys.argv[1]

#open db connection
psql_user = '' #Change this to your username
psql_db = '' #Change this to your personal DB name
psql_password = '' #Put your password (as a string) here
psql_server = '' #Put the server name here
psql_port = #Put the port (as an int) here

conn = psycopg2.connect(dbname=psql_db,user=psql_user,password=psql_password,host=psql_server,port=psql_port)
cursor = conn.cursor()

cursor.execute("select name from students where id = %s", (student_id,))
for x in cursor:
	student_name = x[0]
print_header(student_id, student_name)

cursor.execute("select enrollment.term, enrollment.course_code, course_offerings.name, grades.grade from enrollment left join grades on enrollment.student_id = grades.student_id and enrollment.course_code = grades.course_code and enrollment.term = grades.term left join course_offerings on enrollment.course_code = course_offerings.course_code and enrollment.term = course_offerings.term where enrollment.student_id = %s order by enrollment.term, enrollment.course_code;", (student_id,))
for row in cursor:
	term, course_code, course_name, grade = row[0:4]
	print_row(term,course_code,course_name,grade)

conn.commit()
cursor.close()
conn.close()
