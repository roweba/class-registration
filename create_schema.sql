--Name: Rowena Zhu

drop table if exists students cascade;
drop table if exists courses cascade;
drop table if exists course_offerings cascade;
drop table if exists prerequisites cascade;
drop table if exists enrollment cascade;
drop table if exists grades cascade;
drop function if exists students_ignore_duplicates() cascade;
drop function if exists courses_ignore_duplicates() cascade;
drop function if exists course_offerings_ignore_duplicates() cascade;
drop function if exists prerequisite_number_constraint() cascade;
drop function if exists enrollment_ignore_duplicates() cascade;
drop function if exists valid_course_offering() cascade;
drop function if exists courses_capacity_constraint() cascade;
drop function if exists student_has_prerequisites() cascade;
drop function if exists grade_drop_constraint() cascade;
drop function if exists prerequisites_ignore_duplicates() cascade;
drop function if exists grades_ignore_duplicates() cascade;

create table students(
  id varchar(9) primary key,
  name varchar(255)
);

create table courses(
  code varchar(10) primary key
);

create table course_offerings(
  course_code varchar(10),
  name varchar(128) not null,
  term integer,
  instructor varchar(50) not null,
  capacity integer,
  primary key(course_code,term),
  foreign key(course_code) references courses(code)
    on delete cascade
    on update cascade,
  check(capacity > 0)
);

create table enrollment(
  student_id varchar(9),
  course_code varchar(100),
  term integer,
  primary key(student_id,course_code,term),
  foreign key(student_id)
    references students(id)
    on delete cascade
    on update cascade,
  foreign key(course_code, term)
    references course_offerings(course_code,term)
    on delete cascade
    on update cascade
);

create table prerequisites(
  course_code varchar(10),
  term integer,
  prerequisite varchar(10),
  primary key(course_code,term,prerequisite),
  foreign key(course_code,term) references course_offerings(course_code,term)
    on delete cascade
    on update cascade,
  foreign key(prerequisite) references courses(code)
    on delete cascade
    on update cascade
);

create table grades(
  student_id varchar(9),
  course_code varchar(100),
  term integer,
  grade integer,
  primary key(student_id,course_code,term),
  foreign key(student_id)
    references students(id)
    on delete cascade
    on update cascade,
  foreign key(course_code, term)
    references enrollment(course_code,term)
    on delete cascade
    on update cascade,
  check(grade >= 0 AND grade <= 100)
);

--ignore a duplicate insertion on students
create function students_ignore_duplicates()
returns trigger as
$BODY$
begin
if (select count(*)
    from students
    where id = new.id and name = new.name) > 0
then
  return NULL;
end if;
return new;
end
$BODY$
language plpgsql;

create trigger students_ignore_duplicates
  before insert on students
  for each row
  execute procedure students_ignore_duplicates();

--ignore a duplicate insertion on courses
create function courses_ignore_duplicates()
returns trigger as
$BODY$
begin
if (select count(*)
    from courses
    where code = new.code) > 0
then
  return NULL;
end if;
return new;
end
$BODY$
language plpgsql;

create trigger courses_ignore_duplicates
  before insert on courses
  for each row
  execute procedure courses_ignore_duplicates();

--ignore a duplicate insertion on course_offerings
create function course_offerings_ignore_duplicates()
returns trigger as
$BODY$
begin
if (select count(*)
    from course_offerings
    where course_code = new.course_code and term = new.term) > 0
then
  return NULL;
end if;
return new;
end
$BODY$
language plpgsql;

create trigger course_offerings_ignore_duplicates
  before insert on course_offerings
  for each row
  execute procedure course_offerings_ignore_duplicates();

--course can only have a max of 2 prerequisites
create function prerequisite_number_constraint()
  returns trigger as
  $BODY$
  begin
  if (select count(*) from prerequisites
      where course_code = new.course_code and term = new.term) > 2
  then
    raise exception 'Course can only have up to 2 prerequisites';
  end if;
  return new;
  end
  $BODY$
  language plpgsql;

create trigger prerequisite_number_constraint
  after insert or update on prerequisites
  for each row
  execute procedure prerequisite_number_constraint();

--ignore a duplicate insertion on enrollment
create function enrollment_ignore_duplicates()
returns trigger as
$BODY$
begin
if (select count(*)
    from enrollment
    where student_id = new.student_id and course_code = new.course_code and term = new.term) > 0
then
  return NULL;
end if;
return new;
end
$BODY$
language plpgsql;

create trigger enrollment_ignore_duplicates
  before insert on enrollment
  for each row
  execute procedure enrollment_ignore_duplicates();

--only enroll students in valid courses
create function valid_course_offering()
returns trigger as
$BODY$
begin
if (select count(*)
    from course_offerings
    where course_code = new.course_code and term = new.term) = 0
then
  return NULL;
end if;
return new;
end
$BODY$
language plpgsql;

create trigger valid_course_offering
  before insert on enrollment
  for each row
  execute procedure valid_course_offering();

--can't enroll in a course that is full
create function courses_capacity_constraint()
returns trigger as
$BODY$
begin
if (select capacity
    from course_offerings
    where course_code = new.course_code and term = new.term
) < (select count(student_id)
    from enrollment where course_code = new.course_code and term = new.term
)
then
  raise exception 'Course is full';
end if;
return new;
end
$BODY$
language plpgsql;

create trigger courses_capacity_constraint
  after insert or update on enrollment
  for each row
  execute procedure courses_capacity_constraint();

--student has the required prerequisites for the given course offering
create function student_has_prerequisites()
  returns trigger as
  $BODY$
  declare
    pre_count int := (select count(*) from prerequisites where course_code = new.course_code and term = new.term);
  begin
  if (select count(*) from prerequisites where course_code = new.course_code and term = new.term) = 0
  then
    return NULL;
  elsif (with
      t1 as (select * from enrollment natural join prerequisites where course_code = new.course_code and student_id = new.student_id),
      t2 as (select prerequisite from t1),
      t3 as (select enrollment.student_id, enrollment.course_code, enrollment.term, grades.grade from t2 inner join enrollment on t2.prerequisite = enrollment.course_code left join grades on t2.prerequisite = grades.course_code and enrollment.student_id = grades.student_id and enrollment.term = grades.term where enrollment.student_id = new.student_id)
      select count(*) from t3 where term < new.term and grade is null or grade >= 50
    ) <> pre_count
  then
    raise exception 'Student does not have the required prerequisites';
  end if;
  return new;
  end
  $BODY$
  language plpgsql;

create constraint trigger student_has_prerequisites
  after insert or update on enrollment
  deferrable
  for each row
  execute procedure student_has_prerequisites();

--student can not drop a course if they have already received a grade
create function grade_drop_constraint()
returns trigger as
$BODY$
begin
if (select count(*)
    from grades
    where grade is not null and student_id = old.student_id and course_code = old.course_code and term = old.term) > 0
then
  raise exception 'ERROR: Can not drop course, grade has already been assigned';
end if;
return new;
end
$BODY$
language plpgsql;

create trigger grade_drop_constraint
  after delete or update on enrollment
  for each row
  execute procedure grade_drop_constraint();

--ignore duplicate prerequisite insertion
create function prerequisites_ignore_duplicates()
returns trigger as
$BODY$
begin
if (select count(*)
    from prerequisites
    where course_code = new.course_code and term = new.term and prerequisite = new.prerequisite) > 0
then
  return NULL;
end if;
return new;
end
$BODY$
language plpgsql;

create trigger prerequisites_ignore_duplicates
  before insert on prerequisites
  for each row
  execute procedure prerequisites_ignore_duplicates();

--only assign a grade for valid courses
create trigger valid_course_offering_grades
  before insert on grades
  for each row
  execute procedure valid_course_offering();

--ignore a duplicate insertion on grades
create function grades_ignore_duplicates()
returns trigger as
$BODY$
begin
if (select count(*)
  from grades
  where student_id = new.student_id and course_code = new.course_code and term = new.term) > 0
then
  return NULL;
end if;
return new;
end
$BODY$
language plpgsql;

create trigger grades_ignore_duplicates
  before insert on grades
  for each row
  execute procedure grades_ignore_duplicates();
