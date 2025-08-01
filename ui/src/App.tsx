import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link, useLocation, Navigate } from 'react-router-dom';
import { DeveloperDashboard } from './components/dashboards/DeveloperDashboard';
import { AdminDashboard } from './components/dashboards/AdminDashboard';
import { DeployServiceForm } from './components/forms/DeployServiceForm';
import { AdminRequests } from './components/AdminRequests';
import { SirwanTestS3Form } from './components/forms/SirwanTestS3Form';
import { Login } from './components/auth/Login';
import { Button } from './components/ui/button';
import { Badge } from './components/ui/badge';
import { useAppStore } from './store/appStore';
import './App.css';

// Protected Route Component
function ProtectedAdminRoute({ children }: { children: React.ReactNode }) {
  const { userRole } = useAppStore();
  
  if (userRole !== 'admin') {
    return <Navigate to="/developer" replace />;
  }
  
  return <>{children}</>;
}

function Navigation() {
  const location = useLocation();
  const { userRole, currentUser, logout } = useAppStore();

  const handleLogout = () => {
    logout();
  };

  // Dynamic portal title based on user role and current route
  const getPortalTitle = () => {
    if (location.pathname === '/admin' || userRole === 'admin') {
      return '🛠️ Admin Portal';
    }
    return '👩‍💻 Developer Portal';
  };

  return (
    <nav className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container mx-auto px-4">
        <div className="flex h-16 items-center justify-between">
          <div className="flex items-center space-x-4">
            <Link to="/" className="text-xl font-bold">
              {getPortalTitle()}
            </Link>
            <div className="hidden md:flex space-x-4">
              {userRole === 'admin' && (
                <>
                  <Link
                    to="/admin"
                    className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                      location.pathname === '/admin'
                        ? 'bg-primary text-primary-foreground'
                        : 'text-muted-foreground hover:text-foreground'
                    }`}
                  >
                    Admin Dashboard
                  </Link>
                  <Link
                    to="/developer"
                    className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                      location.pathname === '/developer'
                        ? 'bg-primary text-primary-foreground'
                        : 'text-muted-foreground hover:text-foreground'
                    }`}
                  >
                    Developer View
                  </Link>
                </>
              )}
              {userRole === 'developer' && (
                <Link
                  to="/developer"
                  className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                    location.pathname === '/developer'
                      ? 'bg-primary text-primary-foreground'
                      : 'text-muted-foreground hover:text-foreground'
                  }`}
                >
                  Developer Dashboard
                </Link>
              )}
            </div>
          </div>
          
          <div className="flex items-center space-x-4">
            <div className="flex items-center space-x-2">
              <span className="text-sm text-muted-foreground">
                Welcome, {currentUser}
              </span>
              <Badge 
                variant={userRole === 'admin' ? 'destructive' : 'secondary'}
                className="text-xs"
              >
                {userRole.toUpperCase()}
              </Badge>
            </div>
            <Button variant="outline" size="sm" onClick={handleLogout}>
              Logout
            </Button>
          </div>
        </div>
      </div>
    </nav>
  );
}

function App() {
  const { isAuthenticated, login, userRole } = useAppStore();

  // If not authenticated, show login page
  if (!isAuthenticated) {
    return <Login onLogin={login} />;
  }

  // If authenticated, show the main application
  return (
    <Router>
      <div className="min-h-screen bg-background">
        <Navigation />
        
        <main>
          <Routes>
            {/* Default route redirects based on user role */}
            <Route path="/" element={
              userRole === 'admin' ? <Navigate to="/admin" replace /> : <Navigate to="/developer" replace />
            } />
            <Route path="/developer" element={<DeveloperDashboard />} />
            <Route path="/admin" element={
              <ProtectedAdminRoute>
                <AdminDashboard />
              </ProtectedAdminRoute>
            } />
            <Route path="/deploy" element={
              <div className="container mx-auto px-4 py-8">
                <DeployServiceForm />
              </div>
            } />
            <Route path="/sirwan-test-s3" element={
              <div className="container mx-auto px-4 py-8">
                <SirwanTestS3Form isAdmin={userRole === 'admin'} />
              </div>
            } />
            <Route path="/admin/requests" element={
              <AdminRequests userRole={userRole} />
            } />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;
