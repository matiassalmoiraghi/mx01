using System;
using System.Collections.Generic;
using System.Text;
using System.Security.Cryptography.X509Certificates;
using System.Security.Cryptography;
using System.Security.Permissions;
using System.IO;


using System.Xml;
using Comun;

namespace Encriptador
{
    public class PAC
    {
        private XmlDocument _comprobanteFiscal;
        //public int numErr =0;
        //public string msjError = "";
        
        interfactura.WebService1 _ws;

        private String _uuid = "";

        public String Uuid
        {
            get { return _uuid; }
//            set { _uuid = value; }
        }

        public PAC(string rutaPAC,string rutaPfx, string clave, Parametros param, out string msj_pac)
        {
            try
            {
                _ws = new interfactura.WebService1();
                _ws.ClientCertificates.Add(new X509Certificate(rutaPfx, clave));
                //_ws.ClientCertificates.Add(new X509Certificate(rutaPAC));
                _ws.Url = param.URLwebServPAC;

                msj_pac = "...Certificados agregados" + Environment.NewLine;
                foreach (X509Certificate x509 in _ws.ClientCertificates)
                {
                    try
                    {
                        msj_pac += "..Certificado : " + x509.ToString(true);
                        x509.Reset();
                    }
                    catch (CryptographicException)
                    {
                        Console.WriteLine("Information could not be written out for this certificate.");
                    }
                }

            }
            catch (Exception ti)
            {
                throw new System.IO.IOException("Exceptión al cargar el certificado. Verifique la existencia del archivo: " + rutaPfx, ti);
            }
        }

        public XmlDocument comprobanteFiscal
        {
            get { return _comprobanteFiscal; }
            set { _comprobanteFiscal = value; }
        }

        /// <summary>
        /// Obtiene el timbre del PAC y lo agrega al cfd.
        /// Debe asignar la propiedad _comprobanteFiscal antes de usar este método.
        /// 26/5/15 jcf Obtiene atributo uuid
        /// </summary>
        /// <returns></returns>
        public void timbraCFD()
        {
            XmlDocument timbre = new XmlDocument();
            XmlNode nodoTimbre = null;
            XmlNamespaceManager nsmgr = new XmlNamespaceManager(_comprobanteFiscal.NameTable);
            nsmgr.AddNamespace("tfd", "http://www.sat.gob.mx/TimbreFiscalDigital");
            nsmgr.AddNamespace("cfdi", "http://www.sat.gob.mx/cfd/3");
            try
            {
                //true: Retorna sólo timbre
                timbre.LoadXml(_ws.GeneraTimbre(_comprobanteFiscal.OuterXml, true));  

                //pruebas
                //numErr++;
                //timbre.Load(@"C:\GPUsuario\GPExpressCfdi\fePRUEBA\timbreresultado.txt");

                //Si el resultado es OK, agregar el nodo al comprobante
                if (timbre.SelectSingleNode("/Resultado/@IdRespuesta").Value.Equals("1"))
                {
                    nodoTimbre = timbre.SelectSingleNode("/Resultado/tfd:TimbreFiscalDigital", nsmgr);
                    XmlNode nodoTimbreImportado = _comprobanteFiscal.ImportNode(nodoTimbre, true);
                    _comprobanteFiscal.SelectSingleNode("/cfdi:Comprobante/cfdi:Complemento", nsmgr).AppendChild(nodoTimbreImportado);
                    _uuid = timbre.SelectSingleNode("/Resultado/tfd:TimbreFiscalDigital/@UUID", nsmgr).Value;
                }
                else
                {
                    String msjError = timbre.SelectSingleNode("/Resultado/@IdRespuesta").Value + " " + timbre.SelectSingleNode("Resultado/@Descripcion").Value;
                    msjError += Environment.NewLine + ". Error reportado por el PAC al timbrar el comprobante." +Environment.NewLine;
                    msjError += "..... URL: " + _ws.Url + Environment.NewLine;
                   
                   
                    msjError += timbre.OuterXml.ToString();
                    throw new ArgumentException(msjError);
                }
            }
            catch
            {
                throw;
            }
        }
    }
}
