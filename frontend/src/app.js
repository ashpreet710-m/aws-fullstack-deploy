import React, {useEffect, useState} from "react";

export default function App() {
  const [msg, setMsg] = useState('loading...');
  useEffect(() => {
    fetch('/api/hello')
      .then(r => r.json())
      .then(d => setMsg(`${d.message} (instance: ${d.instance})`))
      .catch(() => setMsg('Backend not reachable'));
  }, []);
  return (
    <div style={{textAlign:'center', marginTop:60}}>
      <h1>Full-stack on AWS + ALB</h1>
      <p>{msg}</p>
      <p>Frontend served from Nginx, backend behind ALB.</p>
    </div>
  );
}
