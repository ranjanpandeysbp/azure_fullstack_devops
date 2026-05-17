import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  Box, Button, Typography, Paper, Grid, Chip,
  CircularProgress, Alert, Divider, Avatar
} from '@mui/material';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import EditIcon from '@mui/icons-material/Edit';
import { employeeApi } from '../services/api';

export default function EmployeeDetail() {
  const navigate = useNavigate();
  const { id } = useParams();
  const [employee, setEmployee] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    employeeApi.getById(id)
      .then(res => setEmployee(res.data))
      .catch(err => setError(err.message))
      .finally(() => setLoading(false));
  }, [id]);

  if (loading) return <Box sx={{ display: 'flex', justifyContent: 'center', mt: 6 }}><CircularProgress /></Box>;
  if (error) return <Alert severity="error">{error}</Alert>;
  if (!employee) return null;

  const initials = `${employee.firstName?.[0]}${employee.lastName?.[0]}`.toUpperCase();

  return (
    <Box maxWidth={700} mx="auto">
      <Button startIcon={<ArrowBackIcon />} onClick={() => navigate('/')} sx={{ mb: 2 }}>Back</Button>
      <Paper elevation={3} sx={{ p: 4 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 3, mb: 3 }}>
          <Avatar sx={{ width: 72, height: 72, fontSize: 28, bgcolor: 'primary.main' }}>{initials}</Avatar>
          <Box>
            <Typography variant="h5" fontWeight={700}>
              {employee.firstName} {employee.lastName}
            </Typography>
            <Typography color="text.secondary">{employee.position}</Typography>
            <Chip label={employee.department} color="primary" size="small" sx={{ mt: 0.5 }} />
          </Box>
        </Box>
        <Divider sx={{ mb: 3 }} />
        <Grid container spacing={2}>
          {[
            { label: 'Employee ID', value: `#${employee.id}` },
            { label: 'Email', value: employee.email },
            { label: 'Department', value: employee.department },
            { label: 'Position', value: employee.position },
            { label: 'Salary', value: employee.salary ? `$${employee.salary.toLocaleString()}` : '—' },
            { label: 'Created', value: employee.createdAt ? new Date(employee.createdAt).toLocaleDateString() : '—' },
          ].map(({ label, value }) => (
            <Grid item xs={12} sm={6} key={label}>
              <Typography variant="caption" color="text.secondary" fontWeight={600}>{label}</Typography>
              <Typography variant="body1">{value}</Typography>
            </Grid>
          ))}
        </Grid>
        <Box sx={{ mt: 4 }}>
          <Button variant="contained" startIcon={<EditIcon />}
            onClick={() => navigate(`/employees/${id}/edit`)}>
            Edit Employee
          </Button>
        </Box>
      </Paper>
    </Box>
  );
}
