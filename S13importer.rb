#Semester is Spring 2012

class OldBase < ActiveRecord::Base
  self.abstract_class = true
  establish_connection "old"
end

class OldUser < OldBase
  set_table_name 'users'

  has_many :authentications,
            :class_name => "OldAuthentication",
            :foreign_key => "user_id"
  has_many :schedules,
            :class_name => "OldSchedule",
            :foreign_key => "user_id"
  has_many :statuses,
            :class_name => "OldStatus",
            :foreign_key => "user_id"
  def to_model
    user = User.new do |u|
      name = self.name.split(/\ ([^\ ]*)$/)
      u.first_name = name.first
      u.last_name = name.last
      u.uid  = self.uid.to_s
      u.discoverable = self.discoverable
      u.created_at = self.created_at
      u.updated_at = self.updated_at
      u.school_id = School.find_by_name("Carnegie Mellon University").id 
    end
    user.save!(validate: false)
    user.reload
  end
end

class OldSchedule < OldBase
  set_table_name 'schedules' 

  belongs_to :user,
    :class_name => "OldUser"

  belongs_to :semester,
    :class_name => "OldSemester"

  has_many :course_selections,
    :class_name => "OldCourseSelection",
    :foreign_key => "schedule_id"

  def to_model
    new_sched = Schedule.create! do |s|
      user = OldUser.find(self.user_id) 
      if (self.user_id == 1230) # weird bug where a user Lana Li had a 0 semester_id
        self.semester_id = 3
      end
      s.user_id = User.find_by_uid(user.uid).id
      s.name = self.name
      sem = OldSemester.find(self.semester_id) 
      s.semester_id = Semester.find_by_name(sem.name).id
      s.primary = self.primary
      s.url = self.url
      s.created_at = self.created_at
      s.updated_at = self.updated_at
    end
    self.course_selections.each do |old_cs|
      new_sched_course_db = ScheduledCourse.create! do |new_sc|
        new_sc.course_id = Course.find_by_number_and_semester_id(old_cs.section.course.number, Semester.find_by_name(self.semester.name).id).id
        new_sc.schedule_id = new_sched.id
      end
      ScheduledSection.create! do |new_ss|
        puts "" 
        p new_sched_course_db.course
        puts ""
        puts old_cs.section.letter 
        puts ""
   
        new_ss.section_id = Section.by_course(new_sched_course_db.course).find_by_identifier(old_cs.section.letter).id
        new_ss.scheduled_course_id = new_sched_course_db.id 
      end
    end
  end
end

class OldCourse < OldBase
  set_table_name 'courses'

  has_many :sections,
    :class_name => "OldSection",
    :foreign_key => "course_id"
 
  has_many :lectures,
    :class_name => "OldLecture",
    :foreign_key => "course_id"

  has_many :course_selections, :through => :sections,
    :class_name => "OldCourseSelection",
    :foreign_key => "course_id"

  belongs_to :semester,
    :class_name => "OldSemester"

  belongs_to :department,
    :class_name => "OldDepartment"

  def to_model
    Course.create! do |c|
      c.number = self.number
      c.name = self.name
      c.units = self.units
      c.description = self.units
      c.prereqs = self.prereqs
      c.coreqs = self.coreqs
      sem = OldSemester.find(self.semester_id) 
      c.semester_id = Semester.find_by_name(sem.name).id
      dep = OldDepartment.find(self.department_id) 
      c.department_id = Department.find_by_name(dep.name).id
      c.offered = self.offered
      c.created_at = self.created_at
      c.updated_at = self.updated_at 
    end
  end
end

class OldLecture < OldBase
  set_table_name 'lectures'

  has_many :sections,
    :class_name => "OldSection",
    :foreign_key => "lecture_id"

  has_many :scheduled_times, 
    :class_name => "OldScheduledTime", :as => :schedulable,
    :foreign_key => "lecture_id"

  has_many :course_selections,
    :class_name => "OldCourseSelection",
    :foreign_key => "lecture_id"

  has_many :schedules, :through => :course_selections,
    :class_name => "OldSchedule",
    :foreign_key => "lecture_id"

  belongs_to :course,
    :class_name => "OldCourse"

  def to_model
    section_from_db = Section.create! do |s|
      s.offered = true
      course = Course.find_by_number_and_semester_id(self.course.number, Semester.find_by_name(self.course.semester.name).id)             
      group = Group.create!(:course_id => course.id, :name => self.number) 
      s.group_id = group.id
      s.section_type_id = SectionType.find_by_name("Lecture").id
      s.identifier = self.number
      Instructor.find_or_create_by_school_id_and_first_name_and_last_name_and_identifier!(School.find_by_name("Carnegie Mellon University").id, "", self.instructor, self.instructor)
      s.units = ""
      s.created_at = self.created_at
      s.updated_at = self.updated_at
    end
    self.sections.each do |old_section|
      Section.create! do |new_section| 
        new_section.offered = true
        new_section.group_id = section_from_db.group.id
        new_section.section_type_id = SectionType.find_by_name("Recitation").id
        new_section.identifier = old_section.letter
        Instructor.find_or_create_by_school_id_and_first_name_and_last_name_and_identifier!(School.find_by_name("Carnegie Mellon University").id, "", old_section.instructor, old_section.instructor)
        new_section.units = ""
        new_section.created_at = old_section.created_at
        new_section.updated_at = old_section.updated_at
      end  
    end
  end
end

class OldSection < OldBase
  set_table_name 'sections'

  belongs_to :course,
    :class_name => "OldCourse"
  belongs_to :lecture,
    :class_name => "OldLecture"

  has_many :scheduled_times, 
    :class_name => "OldScheduledTime", :as => :schedulable,
    :foreign_key => "schedulable_id"

  has_many :course_selections,
    :class_name => "OldCourseSelection",
    :foreign_key => "section_id"

  has_many :schedules, :through => :course_selctions,
    :class_name => "OldSchedule",
    :foreign_key => "section_id"
  
  def to_model()
    #Only create a section, if the oldSection does not have a lecture
    if self.lecture.nil?
      section_db = Section.create! do |new_section|
        course = Course.find_by_number_and_semester_id(self.course.number, Semester.find_by_name(self.course.semester.name).id) 
        new_section.offered = true
        new_section.group_id = Group.find_or_create_by_course_id_and_name!(course.id, nil).id
        new_section.offered = true
        new_section.section_type_id = SectionType.find_by_name("Lecture").id
        new_section.identifier = self.letter
        Instructor.find_or_create_by_school_id_and_first_name_and_last_name_and_identifier!(School.find_by_name("Carnegie Mellon University").id, "", self.instructor, self.instructor)
        new_section.units = ""
        new_section.created_at = self.created_at
        new_section.updated_at = self.updated_at
      end 
      # Loop through scheduled times of the old section
      # create meetings, buildings, rooms
      # Also using the old scheduled_times model
      scheduled_times = OldScheduledTime.find_all_by_schedulable_id_and_schedulable_type(self.id, "Section") 
      scheduled_times.each do |st|
        room_db = Room.create! do |r|
          loc_arr = st.location.split(/\ ([^\ ]*)$/) 
          r.building_id = Building.find_or_create_by_school_id_and_name_and_short_name!(School.find_by_name("Carnegie Mellon University").id, loc_arr.first, loc_arr.first).id
          r.name = loc_arr.last
        end
        st.days.split("").each do |day|
          Meeting.create! do |m|
            m.section_id = section_db.id
            m.room_id = room_db.id
            m.day = 'UMTWRFS'.index(day)
            m.begin_time = st.begin
            m.end_time = st.end
            m.created_at = st.created_at
            m.updated_at = st.updated_at
          end
        end
      end
    end
  end
end

class OldCourseSelection < OldBase
  set_table_name 'course_selections'

  belongs_to :schedule,
    :class_name => "OldSchedule"
  
  belongs_to :section,
    :class_name => "OldSection"

  def to_model
     
  end
end

class OldAuthentication < OldBase
  set_table_name 'authentications'

  belongs_to :user,
    :class_name => "OldUser"

  def to_model
    Authentication.create! do |a|
      a.user_id = User.find_by_uid(self.uid).id
      a.provider = self.provider
      a.uid = self.uid
      a.created_at = self.created_at
      a.updated_at = self.updated_at
      a.token = self.token
    end
  end
end

class OldDepartment < OldBase
  set_table_name 'departments'

  has_many :courses,
    :class_name => "OldCourse",
    :foreign_key => "department_id"

  def to_model
    Department.create! do |d|
      d.prefix = self.prefix
      d.name = self.name
      d.created_at = self.created_at
      d.updated_at = self.updated_at
      d.school_id = School.find_by_name("Carnegie Mellon University") #hard coded for CMU
    end
  end
end

class OldScheduledTime < OldBase
  set_table_name 'scheduled_times'

  belongs_to :schedulable, :polymorphic => true #FIXME wut...  Lecture or section

  def to_model
      
  end
end

class OldSemester < OldBase
  set_table_name 'semesters'

  has_many :courses,
    :class_name => "OldSemester",
    :foreign_key => "semester_id"
  has_many :schedules,
    :class_name => "OldSchedule",
    :foreign_key => "semester_id"

  def to_model
    Semester.create! do |s|
      s.name = self.name
      s.short_name = self.short_name
      s.current = self.current
      s.school_id = School.find_by_name("Carnegie Mellon University").id
      s.created_at = self.created_at
      s.updated_at = self.updated_at
    end
  end
end

class Importer < ActiveRecord::Base
  self.abstract_class = true
  
  def self.import_all
   old_logger = ActiveRecord::Base.logger
   #ActiveRecord::Base.logger = nil

    if(!School.find_by_name("Carnegie Mellon University")) 
      School.create! do |s|
        s.name = "Carnegie Mellon University"
        s.short_name = "cmu"
        s.domain = "cmu.edu"
      end
    end
    if(!SectionType.find_by_name("Lecture"))
      SectionType.create!(:name => "Lecture", :short_name => "Lec") 
    end
    if(!SectionType.find_by_name("Recitation"))
      SectionType.create!(:name => "Recitation", :short_name => "Rec") 
    end
    OldUser.all.each do |u|
      puts "Importing user: #{u.name}" 
      u.to_model() 
    end
    OldAuthentication.all.each do |a|
      puts "Importing authentication: #{a.id}"
      if !a.uid.nil? 
        a.to_model()
      else
        puts "Hit a bad authentication object"
        p a
      end
    end
    OldDepartment.all.each do |d|
      puts "Importing department: #{d.name}"
      d.to_model() 
    end
    OldSemester.all.each do |s|
      puts "Importing semster: #{s.name}"
      s.to_model() 
    end
    OldCourse.all.each do |c|
      puts "Importing course: #{c.name}"
      c.to_model()
    end
    OldLecture.all.each do |l|
      puts "Importing lecture: #{l.id}"
      l.to_model()
    end
    OldSection.all.each do |s|
      puts "Importing section: #{s.id}"
      s.to_model() 
    end
    OldSchedule.all.each do |s|
      puts "Importing schedule: #{s.name}" 
      s.to_model()
    end
    return nil 
  end
  def self.delete_all
    Authentication.delete_all
    Meeting.delete_all
    Room.delete_all
    Building.delete_all
    ScheduledSection.delete_all
    ScheduledCourse.delete_all
    Lecture.delete_all 
    Section.delete_all
    Group.delete_all
    Instructor.delete_all
    Course.delete_all 
    Department.delete_all
    Schedule.delete_all 
    User.delete_all
    Semester.delete_all   
  end
end
