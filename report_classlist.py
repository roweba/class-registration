import psycopg2, sys

def print_header(course_code, course_name, term, instructor_name):
	print("Class list for %s (%s)"%(str(course_code), str(course_name)) )
	print("  Term %s"%(str(term), ) )
	print("  Instructor: %s"%(str(instructor_name), ) )

def print_row(student_id, student_name, grade):
	if grade is not None:
		print("%10s %-25s   GRADE: %s"%(str(student_id), str(student_name), str(grade)) )
	else:
		print("%10s %-25s"%(str(student_id), str(student_name),) )

def print_footer(total_enrolled, max_capacity):
	print("%s/%s students enrolled"%(str(total_enrolled),str(max_capacity)) )

if len(sys.argv) < 3:
	print('Usage: %s <course code> <term>'%sys.argv[0], file=sys.stderr)
	sys.exit(0)

course_code, term = sys.argv[1:3]

#open db connection
psql_user = '' #Change this to your username
psql_db = '' #Change this to your personal DB name
psql_password = '' #Put your password (as a string) here
psql_server = '' #Put the server name here
psql_port = #Put the port (as an int) here

conn = psycopg2.connect(dbname=psql_db,user=psql_user,password=psql_password,host=psql_server,port=psql_port)
cursor = conn.cursor()

#get header
cursor.execute("select * from course_offerings where course_code = %s and term = %s;", (course_code, term))
for row in cursor:
	course_code, course_name, course_term, instructor_name, capacity = row[0:5]
print_header(course_code, course_name, course_term, instructor_name)

#get students
cursor.execute("select enrollment.student_id, enrollment.course_code, enrollment.term, grades.grade, students.name from enrollment left join grades on enrollment.student_id = grades.student_id and enrollment.course_code = grades.course_code and enrollment.term = grades.term inner join students on students.id = enrollment.student_id where enrollment.course_code = %s and enrollment.term = %s;", (course_code,term))
for row in cursor:
	student_id, course_code, term, grade, student_name = row[0:5]
	print_row(student_id, student_name, grade)

#get footer
cursor.execute("select count(*) from enrollment where course_code = %s and term = %s;", (course_code, term))
for record in cursor:
	count = record[0]
print_footer(count,capacity)

conn.commit()
cursor.close()
conn.close()
