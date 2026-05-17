# Employee Management System
## React + Spring Boot + Azure SQL — Full Stack on Azure

A complete CRUD application with:
- **Frontend**: ReactJS (MUI, React Router, Axios, React Hook Form)
- **Backend**: Spring Boot 3 + JPA (H2 locally, Azure SQL on Azure)
- **Cloud**: Azure App Service, Azure SQL, Key Vault, Application Insights
- **DevOps**: Azure YAML Pipelines with Blue-Green deployment
- **IaC**: Bicep + Azure CLI scripts

---

## Quick Start (Local Development)

### Backend (H2 in-memory DB)
```bash
cd backend
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
# API available at: http://localhost:8080
# H2 Console at:   http://localhost:8080/h2-console
# Health check:    http://localhost:8080/api/health
```

### Frontend
```bash
cd frontend
npm install
npm start
# App available at: http://localhost:3000
```

---

## Project Structure
```
├── frontend/                    # React application
│   ├── src/
│   │   ├── components/          # EmployeeList, EmployeeForm, EmployeeDetail
│   │   ├── services/api.js      # Axios API client
│   │   └── App.js               # Router + Theme
│   ├── .env.development         # Local API URL
│   └── .env.production          # Production API URL
│
├── backend/                     # Spring Boot application
│   ├── src/main/java/com/azure/demo/
│   │   ├── model/Employee.java
│   │   ├── repository/EmployeeRepository.java
│   │   ├── service/EmployeeService.java
│   │   └── controller/EmployeeController.java
│   ├── src/main/resources/
│   │   ├── application.yml            # Base config
│   │   ├── application-local.yml      # H2 profile
│   │   ├── application-azure.yml      # Azure SQL profile
│   │   └── data-local.sql             # Seed data
│   └── pom.xml
│
├── infrastructure/
│   ├── bicep/main.bicep         # Full Bicep IaC template
│   └── cli-scripts/
│       ├── deploy-infrastructure.sh   # Full CLI deployment
│       └── cleanup.sh                 # Delete all resources
│
└── pipelines/
    ├── azure-pipelines-frontend.yml   # React CI/CD pipeline
    └── azure-pipelines-backend.yml    # Spring Boot CI/CD pipeline
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/employees | Get all employees |
| GET | /api/employees/{id} | Get employee by ID |
| POST | /api/employees | Create employee |
| PUT | /api/employees/{id} | Update employee |
| DELETE | /api/employees/{id} | Delete employee |
| GET | /api/employees/search?keyword=X | Search employees |
| GET | /api/employees/departments | List departments |
| GET | /api/health | Health check |

---

## Deploy to Azure

### Option 1: CLI Script
```bash
bash infrastructure/cli-scripts/deploy-infrastructure.sh dev
```

### Option 2: Bicep
```bash
az deployment group create \
  --resource-group rg-emp-dev \
  --template-file infrastructure/bicep/main.bicep \
  --parameters environment=dev sqlAdminPassword='YourP@ss123!'
```
