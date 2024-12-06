CREATE DATABASE EmployeeDB;

USE EmployeeDB;

CREATE TABLE Employee (
    EmployeeID INT PRIMARY KEY IDENTITY(1,1),
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Department NVARCHAR(50),
    HireDate DATETIME
);

-- Insert some sample data
INSERT INTO Employee (FirstName, LastName, Department, HireDate) VALUES ('John', 'Doe', 'Engineering', '2015-06-15'),('Jane', 'Smith', 'Marketing', '2018-08-22'),('Robert', 'Johnson', 'Sales', '2020-01-10'),('Emily', 'Davis', 'Engineering', '2017-11-30'),('Michael', 'Brown', 'HR', '2019-03-05');
