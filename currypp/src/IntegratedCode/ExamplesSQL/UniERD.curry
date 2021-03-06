-- ERD specification for university lectures.

import Database.ERD

uniERD :: ERD
uniERD =
 ERD "Uni"
   [Entity "Student"
           [Attribute "Name" (StringDom Nothing) NoKey False,
            Attribute "Firstname" (StringDom Nothing) NoKey False,
            Attribute "MatNum" (IntDom Nothing) Unique False,
            Attribute "Email" (StringDom Nothing) Unique False,
            Attribute "Age" (IntDom Nothing) NoKey True],
    Entity "Lecture"
           [Attribute "Title" (StringDom Nothing) NoKey False,
            Attribute "Topic" (StringDom Nothing) NoKey True],
    Entity "Lecturer"
           [Attribute "Name" (StringDom Nothing) NoKey False,
            Attribute "Firstname" (StringDom Nothing) NoKey False],
    Entity "Place"
           [Attribute "Street" (StringDom Nothing) NoKey False,
            Attribute "StrNr" (IntDom Nothing) NoKey False,
            Attribute "RoomNr" (IntDom Nothing) NoKey False], 
    Entity "Time"
           [Attribute "Time" (DateDom Nothing) Unique False],
    Entity "Exam"
           [Attribute "GradeAverage" (FloatDom Nothing) NoKey True],
    Entity "Result"
           [Attribute "Attempt" (IntDom Nothing) NoKey False,  
            Attribute "Grade" (FloatDom Nothing) NoKey True,
            Attribute "Points" (IntDom Nothing) NoKey True]]
   [Relationship "Teaching"
                 [REnd "Lecturer" "taught_by" (Exactly 1),
                  REnd "Lecture" "teaches" (Between 0 Infinite)],
    Relationship "Participation"
                 [REnd "Student" "participated_by" (Between 0 Infinite),
                  REnd "Lecture" "participates" (Between 0 Infinite)],
    Relationship "Taking"
                 [REnd "Result" "has_a" (Between 0 Infinite),
                  REnd "Student" "belongs_to" (Exactly 1)],
    Relationship "Resulting"
                 [REnd "Exam" "result_of" (Exactly 1),
                  REnd "Result" "results_in" (Between 0 Infinite)],
    Relationship "Belonging"
                 [REnd "Exam" "has_a" (Between 0 Infinite),
                  REnd "Lecture" "belongs_to" (Exactly 1)],
    Relationship "ExamDate"
                 [REnd "Exam" "taking_place" (Between 0 Infinite),
                  REnd "Time" "at" (Exactly 1)],
    Relationship "ExamPlace"
                 [REnd "Exam" "taking_place" (Between 0 Infinite),
                  REnd "Place" "in" (Exactly 1)]]