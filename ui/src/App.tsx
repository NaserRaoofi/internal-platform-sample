import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link, useLocation } from 'react-router-dom';
import { DeveloperDashboard } from './components/dashboards/DeveloperDashboard';
import { AdminDashboard } from './components/dashboards/AdminDashboard';
import { DeployServiceForm } from './components/forms/DeployServiceForm';
import { SirwanTestS3Form } from './components/forms/SirwanTestS3Form';
import { Button } from './components/ui/button';
import { useAppStore } from './store/appStore';
import './App.css';

function Navigation() {
  const location = useLocation();
  const { userRole, setUserRole } = useAppStore();

  return (
    <nav className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container mx-auto px-4">
        <div className="flex h-16 items-center justify-between">
          <div className="flex items-center space-x-4">
            <Link to="/" className="text-xl font-bold">
              🚀 Developer Portal
            </Link>
            <div className="hidden md:flex space-x-4">
              <Link
                to="/developer"
                className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                  location.pathname === '/developer'
                    ? 'bg-primary text-primary-foreground'
                    : 'text-muted-foreground hover:text-foreground'
                }`}
              >
                Developer
              </Link>
              <Link
                to="/admin"
                className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                  location.pathname === '/admin'
                    ? 'bg-primary text-primary-foreground'
                    : 'text-muted-foreground hover:text-foreground'
                }`}
              >
                Admin
              </Link>
              <Link
                to="/deploy"
                className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                  location.pathname === '/deploy'
                    ? 'bg-primary text-primary-foreground'
                    : 'text-muted-foreground hover:text-foreground'
                }`}
              >
                Deploy Service
              </Link>
              <Link
                to="/sirwan-test-s3"
                className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                  location.pathname === '/sirwan-test-s3'
                    ? 'bg-primary text-primary-foreground'
                    : 'text-muted-foreground hover:text-foreground'
                }`}
              >
                Sirwan S3 Test
              </Link>
            </div>
          </div>
          
          <div className="flex items-center space-x-4">
            <div className="flex items-center space-x-2">
              <span className="text-sm text-muted-foreground">Role:</span>
              <select
                value={userRole}
                onChange={(e) => setUserRole(e.target.value as 'developer' | 'admin')}
                className="text-sm border rounded px-2 py-1"
              >
                <option value="developer">Developer</option>
                <option value="admin">Admin</option>
              </select>
            </div>
            <Button variant="outline" size="sm">
              👤 Profile
            </Button>
          </div>
        </div>
      </div>
    </nav>
  );
}

function HomePage() {
  const { userRole } = useAppStore();

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="max-w-4xl mx-auto text-center">
        <h1 className="text-4xl font-bold mb-4">
          Welcome to Developer Portal
        </h1>
        <p className="text-xl text-muted-foreground mb-8">
          Your Internal Developer Platform for seamless infrastructure deployment
        </p>
        
        <div className="grid md:grid-cols-2 gap-6 mt-12">
          <div className="p-6 border rounded-lg hover:shadow-lg transition-shadow">
            <div className="text-4xl mb-4">👨‍💻</div>
            <h3 className="text-xl font-semibold mb-2">Developer Dashboard</h3>
            <p className="text-muted-foreground mb-4">
              Deploy services, monitor your applications, and track deployment status
            </p>
            <Link to="/developer">
              <Button className="w-full">Go to Developer Dashboard</Button>
            </Link>
          </div>
          
          <div className="p-6 border rounded-lg hover:shadow-lg transition-shadow">
            <div className="text-4xl mb-4">⚙️</div>
            <h3 className="text-xl font-semibold mb-2">Admin Dashboard</h3>
            <p className="text-muted-foreground mb-4">
              Review requests, approve deployments, and monitor system health
            </p>
            <Link to="/admin">
              <Button className="w-full" variant="outline">Go to Admin Dashboard</Button>
            </Link>
          </div>
        </div>

        <div className="mt-12 p-6 bg-muted rounded-lg">
          <h3 className="text-lg font-semibold mb-2">Quick Actions</h3>
          <div className="flex gap-4 justify-center flex-wrap">
            <Link to="/deploy">
              <Button>🚀 Deploy New Service</Button>
            </Link>
            <Link to="/sirwan-test-s3">
              <Button variant="outline">🪣 Sirwan S3 Test</Button>
            </Link>
            <Button variant="outline">📊 View Analytics</Button>
            <Button variant="outline">📚 Documentation</Button>
          </div>
        </div>

        <div className="mt-8 text-sm text-muted-foreground">
          Currently logged in as: <strong>{userRole}</strong>
        </div>
      </div>
    </div>
  );
}

function App() {
  return (
    <Router>
      <div className="min-h-screen bg-background">
        <Navigation />
        
        <main>
          <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/developer" element={<DeveloperDashboard />} />
            <Route path="/admin" element={<AdminDashboard />} />
            <Route path="/deploy" element={
              <div className="container mx-auto px-4 py-8">
                <DeployServiceForm />
              </div>
            } />
            <Route path="/sirwan-test-s3" element={
              <div className="container mx-auto px-4 py-8">
                <SirwanTestS3Form />
              </div>
            } />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;
