USE [MEX10]
GO


ALTER function [dbo].[fCfdiDocumentoDePagoXML_Nodo_Relacionado] (@RMDTYPAL smallint, @DOCNUMBR varchar(21))
returns xml 
as
--Propósito. Devuelve el nodo DoctoRelacionado
--Requisitos. -
--24/10/2017 lt Creación cfdi
--
begin
	declare @cnp xml;
	WITH XMLNAMESPACES
	(
				'http://www.sat.gob.mx/Pagos' as "pago10"
	)
	select @cnp = 
	(
        SELECT     
        IdDocumento											'@IdDocumento',
		MonedaDR											'@MonedaDR',
		TipoCambioDR										'@TipoCambioDR',
		'PPD'												'@MetodoDePagoDR',
		NumParcialidad										'@NumParcialidad',
		ImpSaldoAnt											'@ImpSaldoAnt',
		ImpPagado											'@ImpPagado',
		ImpSaldoInsoluto									'@ImpSaldoInsoluto'
		from dbo.vwCfdiRMFacturas line
        WHERE  line.DOCNUMBR = @DOCNUMBR
		and line.RMDTYPAL = @RMDTYPAL
        FOR XML PATH ('pago10:DoctoRelacionado'), type

	)
	return @cnp;
end
go

--select [dbo].[fCfdiDocumentoDePagoXML_Nodo_Relacionado] (9, 'PYMNT00000029')