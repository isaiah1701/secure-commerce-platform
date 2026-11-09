import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './styles.css';

const root = document.getElementById('soc-root');
if (!root) {
  throw new Error('The SOC workspace root element is missing.');
}

window.SOCOPS_CONFIG = Object.freeze({
  apiUrl: root.dataset.apiUrl ?? '/plugins/socops/api',
  currentUser: root.dataset.currentUser ?? '',
});

ReactDOM.createRoot(root).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
