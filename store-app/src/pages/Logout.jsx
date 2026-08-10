import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useApp } from '../ctx';

export default function Logout() {
  const { logout } = useApp();
  const nav = useNavigate();
  useEffect(() => { logout(); nav('/'); }, []);
  return null;
}