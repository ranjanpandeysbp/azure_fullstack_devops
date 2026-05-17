import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link, useLocation } from 'react-router-dom';
import {
  AppBar, Toolbar, Typography, Container, Button, Box,
  CssBaseline, createTheme, ThemeProvider
} from '@mui/material';
import PeopleIcon from '@mui/icons-material/People';
import AddIcon from '@mui/icons-material/Add';
import { ToastContainer } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';

import EmployeeList from './components/EmployeeList';
import EmployeeForm from './components/EmployeeForm';
import EmployeeDetail from './components/EmployeeDetail';

const theme = createTheme({
  palette: {
    primary: { main: '#0078D4' },   // Azure Blue
    secondary: { main: '#00B294' }, // Azure Teal
  },
  typography: { fontFamily: '"Segoe UI", Roboto, Arial, sans-serif' },
});

function NavBar() {
  const location = useLocation();
  return (
    <AppBar position="static" elevation={2}>
      <Toolbar>
        <PeopleIcon sx={{ mr: 1 }} />
        <Typography variant="h6" component={Link} to="/"
          sx={{ flexGrow: 1, textDecoration: 'none', color: 'inherit', fontWeight: 700 }}>
          Employee Management
        </Typography>
        <Button
          color="inherit"
          component={Link}
          to="/employees/new"
          startIcon={<AddIcon />}
          variant={location.pathname === '/employees/new' ? 'outlined' : 'text'}
          sx={{ borderColor: 'rgba(255,255,255,0.7)' }}>
          Add Employee
        </Button>
      </Toolbar>
    </AppBar>
  );
}

function App() {
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Router>
        <NavBar />
        <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
          <Routes>
            <Route path="/" element={<EmployeeList />} />
            <Route path="/employees" element={<EmployeeList />} />
            <Route path="/employees/new" element={<EmployeeForm />} />
            <Route path="/employees/:id/edit" element={<EmployeeForm />} />
            <Route path="/employees/:id" element={<EmployeeDetail />} />
          </Routes>
        </Container>
      </Router>
      <ToastContainer position="top-right" autoClose={3000} />
    </ThemeProvider>
  );
}

export default App;
