import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useForm, Controller } from 'react-hook-form';
import {
  Box, Button, TextField, Typography, Paper, Grid,
  MenuItem, CircularProgress, Alert, Divider
} from '@mui/material';
import SaveIcon from '@mui/icons-material/Save';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import { employeeApi } from '../services/api';
import { toast } from 'react-toastify';

const DEPARTMENTS = ['Engineering', 'Product', 'Marketing', 'HR', 'Finance', 'Design', 'Operations', 'Legal'];
const POSITIONS   = ['Junior Developer', 'Senior Developer', 'Lead Developer', 'DevOps Engineer',
                     'Product Manager', 'UX Designer', 'HR Manager', 'Financial Analyst', 'Marketing Lead', 'Director'];

export default function EmployeeForm() {
  const navigate = useNavigate();
  const { id } = useParams();
  const isEdit = Boolean(id);
  const [loading, setLoading] = useState(false);
  const [fetchLoading, setFetchLoading] = useState(isEdit);
  const [error, setError] = useState(null);

  const { control, handleSubmit, reset, formState: { errors } } = useForm({
    defaultValues: {
      firstName: '', lastName: '', email: '',
      department: '', position: '', salary: '',
    }
  });

  useEffect(() => {
    if (!isEdit) return;
    employeeApi.getById(id)
      .then(res => { reset(res.data); })
      .catch(err => setError(err.message))
      .finally(() => setFetchLoading(false));
  }, [id, isEdit, reset]);

  const onSubmit = async (data) => {
    try {
      setLoading(true);
      setError(null);
      const payload = { ...data, salary: data.salary ? parseFloat(data.salary) : null };
      if (isEdit) {
        await employeeApi.update(id, payload);
        toast.success('Employee updated successfully!');
      } else {
        await employeeApi.create(payload);
        toast.success('Employee created successfully!');
      }
      navigate('/');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  if (fetchLoading) return <Box sx={{ display: 'flex', justifyContent: 'center', mt: 6 }}><CircularProgress /></Box>;

  return (
    <Box maxWidth={700} mx="auto">
      <Button startIcon={<ArrowBackIcon />} onClick={() => navigate('/')} sx={{ mb: 2 }}>
        Back to List
      </Button>

      <Paper elevation={3} sx={{ p: 4 }}>
        <Typography variant="h5" fontWeight={700} color="primary" gutterBottom>
          {isEdit ? 'Edit Employee' : 'Add New Employee'}
        </Typography>
        <Divider sx={{ mb: 3 }} />

        {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

        <form onSubmit={handleSubmit(onSubmit)}>
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6}>
              <Controller name="firstName" control={control}
                rules={{ required: 'First name is required', maxLength: { value: 100, message: 'Max 100 chars' } }}
                render={({ field }) => (
                  <TextField {...field} fullWidth label="First Name *"
                    error={!!errors.firstName} helperText={errors.firstName?.message} />
                )} />
            </Grid>
            <Grid item xs={12} sm={6}>
              <Controller name="lastName" control={control}
                rules={{ required: 'Last name is required', maxLength: { value: 100, message: 'Max 100 chars' } }}
                render={({ field }) => (
                  <TextField {...field} fullWidth label="Last Name *"
                    error={!!errors.lastName} helperText={errors.lastName?.message} />
                )} />
            </Grid>
            <Grid item xs={12}>
              <Controller name="email" control={control}
                rules={{ required: 'Email is required',
                  pattern: { value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i, message: 'Invalid email' } }}
                render={({ field }) => (
                  <TextField {...field} fullWidth label="Email *" type="email"
                    error={!!errors.email} helperText={errors.email?.message} />
                )} />
            </Grid>
            <Grid item xs={12} sm={6}>
              <Controller name="department" control={control}
                rules={{ required: 'Department is required' }}
                render={({ field }) => (
                  <TextField {...field} fullWidth select label="Department *"
                    error={!!errors.department} helperText={errors.department?.message}>
                    {DEPARTMENTS.map(d => <MenuItem key={d} value={d}>{d}</MenuItem>)}
                  </TextField>
                )} />
            </Grid>
            <Grid item xs={12} sm={6}>
              <Controller name="position" control={control}
                rules={{ required: 'Position is required' }}
                render={({ field }) => (
                  <TextField {...field} fullWidth select label="Position *"
                    error={!!errors.position} helperText={errors.position?.message}>
                    {POSITIONS.map(p => <MenuItem key={p} value={p}>{p}</MenuItem>)}
                  </TextField>
                )} />
            </Grid>
            <Grid item xs={12} sm={6}>
              <Controller name="salary" control={control}
                rules={{ min: { value: 0, message: 'Must be positive' } }}
                render={({ field }) => (
                  <TextField {...field} fullWidth label="Salary" type="number"
                    InputProps={{ startAdornment: '$' }}
                    error={!!errors.salary} helperText={errors.salary?.message} />
                )} />
            </Grid>
          </Grid>

          <Box sx={{ mt: 4, display: 'flex', gap: 2 }}>
            <Button type="submit" variant="contained" size="large"
              startIcon={loading ? <CircularProgress size={20} color="inherit" /> : <SaveIcon />}
              disabled={loading}>
              {isEdit ? 'Update Employee' : 'Create Employee'}
            </Button>
            <Button variant="outlined" size="large" onClick={() => navigate('/')} disabled={loading}>
              Cancel
            </Button>
          </Box>
        </form>
      </Paper>
    </Box>
  );
}
