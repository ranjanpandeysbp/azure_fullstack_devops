package com.azure.demo.service;

import com.azure.demo.exception.ResourceNotFoundException;
import com.azure.demo.exception.DuplicateEmailException;
import com.azure.demo.model.Employee;
import com.azure.demo.repository.EmployeeRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class EmployeeService {

    private static final Logger logger = LoggerFactory.getLogger(EmployeeService.class);

    private final EmployeeRepository employeeRepository;

    public EmployeeService(EmployeeRepository employeeRepository) {
        this.employeeRepository = employeeRepository;
    }

    @Transactional(readOnly = true)
    public List<Employee> getAllEmployees() {
        logger.info("Fetching all employees");
        return employeeRepository.findAll();
    }

    @Transactional(readOnly = true)
    public Employee getEmployeeById(Long id) {
        logger.info("Fetching employee with id: {}", id);
        return employeeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Employee not found with id: " + id));
    }

    public Employee createEmployee(Employee employee) {
        logger.info("Creating employee with email: {}", employee.getEmail());
        if (employeeRepository.existsByEmail(employee.getEmail())) {
            throw new DuplicateEmailException("Employee already exists with email: " + employee.getEmail());
        }
        Employee saved = employeeRepository.save(employee);
        logger.info("Employee created with id: {}", saved.getId());
        return saved;
    }

    public Employee updateEmployee(Long id, Employee employeeDetails) {
        logger.info("Updating employee with id: {}", id);
        Employee employee = getEmployeeById(id);

        // Check email uniqueness if changed
        if (!employee.getEmail().equals(employeeDetails.getEmail()) &&
            employeeRepository.existsByEmail(employeeDetails.getEmail())) {
            throw new DuplicateEmailException("Email already in use: " + employeeDetails.getEmail());
        }

        employee.setFirstName(employeeDetails.getFirstName());
        employee.setLastName(employeeDetails.getLastName());
        employee.setEmail(employeeDetails.getEmail());
        employee.setDepartment(employeeDetails.getDepartment());
        employee.setPosition(employeeDetails.getPosition());
        employee.setSalary(employeeDetails.getSalary());

        return employeeRepository.save(employee);
    }

    public void deleteEmployee(Long id) {
        logger.info("Deleting employee with id: {}", id);
        Employee employee = getEmployeeById(id);
        employeeRepository.delete(employee);
        logger.info("Employee deleted with id: {}", id);
    }

    @Transactional(readOnly = true)
    public List<Employee> searchEmployees(String keyword) {
        logger.info("Searching employees with keyword: {}", keyword);
        return employeeRepository.searchByKeyword(keyword);
    }

    @Transactional(readOnly = true)
    public List<Employee> getEmployeesByDepartment(String department) {
        return employeeRepository.findByDepartment(department);
    }

    @Transactional(readOnly = true)
    public List<String> getAllDepartments() {
        return employeeRepository.findAllDepartments();
    }
}
