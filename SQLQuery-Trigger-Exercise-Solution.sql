--Triggers Exercise

USE IQSchool
Go

DROP TRIGGER IF EXISTS TR_Max3Clubs_Insert_Update
DROP TRIGGER IF EXISTS TR_CourseCost_Increase_Update
DROP TRIGGER IF EXISTS TR_StudentOwnTooMuch_Insert
DROP TRIGGER IF EXISTS TR_BalanceOwingLog
DROP TRIGGER IF EXISTS TR_BalanceOwingChangeLog_Update
DROP TRIGGER IF EXISTS TR_NoClubIDUpdate_Update
DROP TRIGGER IF EXISTS TR_NoCourseIDUpdate_Update
GO

-- 1.In order to be fair to all students, a student can only belong to a maximum of 3 clubs. 
-- Create a trigger to enforce this rule.
CREATE TRIGGER TR_Max3Clubs_Insert_Update
ON Activity
FOR Insert, Update 
AS
	IF @@ROWCOUNT > 0 AND Update(StudentID)
		BEGIN
			IF EXISTS (SELECT * FROM Activity
							INNER JOIN Inserted
							ON Activity.StudentID = Inserted.StudentID
						GROUP BY Activity.StudentID
						HAVING COUNT(*) > 3)
				BEGIN
					RaisError('Theis student has the maximum clubs.', 16, 1)
					ROLLBACK TRANSACTION
				END
		END
RETURN
GO
-- Test
/*
INSERT INTO Activity
	(StudentID, ClubId)
VALUES
	('200495500', 'NASA')
GO
*/

-- 2.The Education Board is concerned with rising course costs! Create a trigger to ensure 
-- that a course cost does not get increased by more than 20% at any one time.
CREATE TRIGGER TR_CourseCost_Increase_Update
ON Course
FOR Update
AS
	IF @@ROWCOUNT > 0 AND Update(CourseCost)
		BEGIN
			IF EXISTS (SELECT * FROM Inserted
							INNER JOIN Deleted
							ON Inserted.CourseId = Deleted.CourseId
						WHERE Inserted.CourseCost > 1.2 * Deleted.CourseCost)
				BEGIN
					RaisError('The new course cost is too much!', 16, 1)
					ROLLBACK TRANSACTION
				END
		END
RETURN
GO
-- Test
/*
UPDATE Course
	SET CourseCost = 1.5*CourseCost
WHERE Course.CourseId = 'COMP1017'
GO
*/

-- 3.Too many students owe us money and keep registering for more courses! 
-- Create a trigger to ensure that a student cannot register for any more courses 
-- if they have a balance owing of more than $500.
CREATE TRIGGER TR_StudentOwnTooMuch_Insert
ON Registration
FOR Insert
AS
	IF @@ROWCOUNT > 0
		BEGIN
			IF EXISTS (SELECT * FROM Student
							INNER JOIN inserted
							ON Student.StudentID = inserted.StudentID
						WHERE Student.BalanceOwing > 500)
				BEGIN
					RaisError('This student owes too much money already!', 16, 1)
					ROLLBACK TRANSACTION
				END
		END
RETURN
GO
-- Test
/*
UPDATE	Student
	Set BalanceOwing = 501
WHERE StudentID = 199966250

INSERT INTO Registration
	(OfferingCode, StudentID, Mark, WithdrawYN)
VALUES
	(1000, 199966250, 80, 'N')
GO
*/

-- 4.Our network security officer suspects our system has a virus that is allowing students to alter their Balance Owing! 
-- In order to track down what is happening we want to create a logging table that will log any changes to the BalanceOwing column in the student table. 
-- You must create the logging table and the trigger to populate it when a balance owing is updated. 
-- LogID is the primary key and will have Identity (1,1).
CREATE TABLE TR_BalanceOwingLog
(
	LogID INT Identity(1,1)	NOT NULL CONSTRAINT PK_BalanceOwingLog_LogID PRIMARY KEY CLUSTERED,
	StudentID		INT					NOT NULL,
	ChangeDateTime	DATETIME			NOT NULL,
	OldBalance		DECIMAL(7,2)		NOT NULL,
	NewBalance		DECIMAL(7,2)		NOT NULL
)
Go

CREATE TRIGGER TR_BalanceOwingChangeLog_Update
ON Student
FOR Update
AS
	IF @@ROWCOUNT > 0 AND Update(BalanceOwing)
		BEGIN
			INSERT INTO BalanceOwingLog
				(StudentID, ChangeDateTime, OldBalance, NewBalance)
			SELECT inserted.StudentID, GETDATE(), deleted.BalanceOwing, inserted.BalanceOwing
				FROM inserted
					INNER JOIN deleted
					ON inserted.StudentID = deleted.StudentID
			IF @@ERROR <> 0
				BEGIN
					RaisError('Insert Balance owing chang log failed.', 16, 1)
					ROLLBACK TRANSACTION
				END
		END
RETURN
GO
-- Test
/*
Update Student
	Set	BalanceOwing = 1000
Where Student.StudentID = 198933540
GO
*/


-- 5.We have learned it is a bad idea to update primary keys.
-- Yet someone keeps trying to update the Club tables ClubID column and the Course tables CourseID column! 
-- Create a trigger(s) to stop this from happening! You are authorized to use whatever force is necessary! 
-- Well, in your triggers, anyways !
CREATE TRIGGER TR_NoClubIDUpdate_Update
ON Club
FOR Update
AS
	IF @@ROWCOUNT > 0 AND Update(ClubID)
		BEGIN
			RaisError('You cannot update ClubID!', 16, 1)
			ROLLBACK TRANSACTION
		END
RETURN
GO

CREATE TRIGGER TR_NoCourseIDUpdate_Update
ON Course
FOR Update
AS
	IF @@ROWCOUNT > 0 AND Update(CourseID)
		BEGIN
			RaisError('You cannot update CourseID!', 16, 1)
			ROLLBACK TRANSACTION
		END
RETURN
GO