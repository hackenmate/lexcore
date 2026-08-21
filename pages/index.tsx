import Head from 'next/head';
import LegalApp from '../src/LegalApp';
import '../styles/legal.css';

export default function Home() {
  return <><Head><title>LexCore Legal OS</title><meta name='description' content='Sistema operativo jurídico privado con IA sustentada en evidencia' /></Head><LegalApp /></>;
}
