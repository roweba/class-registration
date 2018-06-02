import sys, csv, psycopg2

if len(sys.argv) < 2:
	print("Usage: %s <input file>",file=sys.stderr)
	sys.exit(0)

input_filename = sys.argv[1]

# Open your DB connection here
psql_user = '' #Change this to your username
psql_db = '' #Change this to your personal DB name
psql_password = '' #Put your password (as a string) here
psql_server = '' #Put the server name here
psql_port = #Put the port (as an int) here

conn = psycopg2.connect(dbname=psql_db,user=psql_user,password=psql_password,host=psql_server,port=psql_port)
cursor = conn.cursor()

with open(input_filename) as f:
	for row in csv.reader(f):
		if len(row) == 0:
			continue #Ignore blank rows
		if len(row) < 4:
			print("Error: Invalid input line \"%s\""%(','.join(row)), file=sys.stderr)
			conn.rollback()
			break
		code, name, term, instructor, capacity = row[0:5]
		prerequisites = row[5:] #List of zero or more items

		cursor.execute("insert into courses values(%s);", (code,))
		cursor.execute("insert into course_offerings values(%s, %s, %s, %s, %s);", (code, name, term, instructor, capacity))
		if len(row) > 5:
			cursor.execute("insert into prerequisites values(%s, %s, %s);", (code, term, row[5]))
			if len(row) > 6:
				cursor.execute("insert into prerequisites values(%s, %s, %s);", (code, term, row[6]))
	try:
		conn.commit() #Only commit if no error occurs (commit will actually be prevented if an error occurs anyway)
	except psycopg2.ProgrammingError as err:
		#ProgrammingError is thrown when the database error is related to the format of the query (e.g. syntax error)
		print("Caught a ProgrammingError:",file=sys.stderr)
		print(err,file=sys.stderr)
		conn.rollback()
	except psycopg2.IntegrityError as err:
		print("Caught an IntegrityError:",file=sys.stderr)
		print(err,file=sys.stderr)
		conn.rollback()
	except psycopg2.InternalError as err:
		print("Caught an InternalError:",file=sys.stderr)
		print(err,file=sys.stderr)
		conn.rollback()
conn.commit()
cursor.close()
conn.close()
