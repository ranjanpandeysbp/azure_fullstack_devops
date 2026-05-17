import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Box, Button, TextField, Typography, Paper, Table, TableBody,
  TableCell, TableContainer, TableHead, TableRow, IconButton,
  Chip, InputAdornment, CircularProgress, Alert, Tooltip,
  Dialog, DialogTitle, DialogContent, DialogContentText, DialogActions
} from '@mui/material';
import SearchIcon from '@mui/icons-material/Search';
import EditIcon from '@mui/icons-material/Edit';
import DeleteIcon from '@mui/icons-material/Delete';
import VisibilityIcon from '@mui/icons-material/Visibility';
import RefreshIcon from '@mui/icons-material/Refresh';
import { employeeApi } from '../services/api';
import { toast } from 'react-toastify';

const DEPT_COLORS = {
  Engineering: 'primary', Product: 'secondary', Marketing: 'warning',
  HR: 'success', Finance: 'info', Design: 'error', Default: 'default',
};

export default function EmployeeList() {
  const navigate = useNavigate();
  const [employees, setEmployees] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [search, setSearch] = useState('');
  const [deleteDialog, setDeleteDialog] = useState({ open: false, employee: null });

  const fetchEmployees = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = search.trim()
        ? await employeeApi.search(search.trim())
        : await employeeApi.getAll();
      setEmployees(res.data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [search]);

  useEffect(() => {
    const timer = setTimeout(fetchEmployees, search ? 400 : 0);
    return () => clearTimeout(timer);
  }, [fetchEmployees, search]);

  const handleDelete = async () => {
    const { employee } = deleteDialog;
    try {
      await employeeApi.delete(employee.id);
      toast.success(`${employee.firstName} ${employee.lastName} deleted`);
      setDeleteDialog({ open: false, employee: null });
      fetchEmployees();
    } catch (err) {
      toast.error(err.message);
    }
  };

  const deptColor = (dept) => DEPT_COLORS[dept] || DEPT_COLORS.Default;

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" fontWeight={700} color="primary">
          Employees ({employees.length})
        </Typography>
        <Box sx={{ display: 'flex', gap: 1 }}>
          <Tooltip title="Refresh">
            <IconButton onClick={fetchEmployees} color="primary"><RefreshIcon /></IconButton>
          </Tooltip>
          <Button variant="contained" onClick={() => navigate('/employees/new')}>
            + Add Employee
          </Button>
        </Box>
      </Box>

      <TextField
        fullWidth
        placeholder="Search by name, email, or department…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        InputProps={{
          startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment>,
        }}
        sx={{ mb: 3 }}
      />

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 6 }}>
          <CircularProgress />
        </Box>
      ) : employees.length === 0 ? (
        <Paper sx={{ p: 6, textAlign: 'center' }}>
          <Typography color="text.secondary">
            {search ? `No employees found for "${search}"` : 'No employees yet. Add one!'}
          </Typography>
        </Paper>
      ) : (
        <TableContainer component={Paper} elevation={2}>
          <Table>
            <TableHead>
              <TableRow sx={{ bgcolor: 'primary.main' }}>
                {['ID', 'Name', 'Email', 'Department', 'Position', 'Salary', 'Actions'].map(h => (
                  <TableCell key={h} sx={{ color: 'white', fontWeight: 700 }}>{h}</TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {employees.map((emp, i) => (
                <TableRow key={emp.id} hover sx={{ bgcolor: i % 2 ? '#fafafa' : 'white' }}>
                  <TableCell>{emp.id}</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>{emp.firstName} {emp.lastName}</TableCell>
                  <TableCell>{emp.email}</TableCell>
                  <TableCell>
                    <Chip label={emp.department} color={deptColor(emp.department)} size="small" />
                  </TableCell>
                  <TableCell>{emp.position}</TableCell>
                  <TableCell>${emp.salary?.toLocaleString() ?? '—'}</TableCell>
                  <TableCell>
                    <Tooltip title="View">
                      <IconButton size="small" color="info" onClick={() => navigate(`/employees/${emp.id}`)}>
                        <VisibilityIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Edit">
                      <IconButton size="small" color="primary" onClick={() => navigate(`/employees/${emp.id}/edit`)}>
                        <EditIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Delete">
                      <IconButton size="small" color="error" onClick={() => setDeleteDialog({ open: true, employee: emp })}>
                        <DeleteIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      {/* Delete Confirmation */}
      <Dialog open={deleteDialog.open} onClose={() => setDeleteDialog({ open: false, employee: null })}>
        <DialogTitle>Confirm Delete</DialogTitle>
        <DialogContent>
          <DialogContentText>
            Are you sure you want to delete{' '}
            <strong>{deleteDialog.employee?.firstName} {deleteDialog.employee?.lastName}</strong>?
            This action cannot be undone.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDeleteDialog({ open: false, employee: null })}>Cancel</Button>
          <Button onClick={handleDelete} color="error" variant="contained">Delete</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
