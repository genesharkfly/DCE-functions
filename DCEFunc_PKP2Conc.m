function [Ct_mM,IRF]=DCEFunc_PKP2Conc(tRes_s,Cp_AIF_mM,PKP,model,opts)
% Calculate tissue concentration curve based on pharmacokinetic parameters
% Output:
% Ct_mM: column vector giving tissue concentration in mM
% IRF: impulse response function
% Input:
% tRes_s = time resolution in seconds
% Cp_AIF_mM = column vector giving AIF plasma concentration in mM
% PKP = struct containing PK parameters (vP, vE, PS_perMin, FP_mlPer100gPerMin)
% model = string to specify model ('Patlak' or '2CXM').
% opts = struct containing options

N=size(Cp_AIF_mM,1);

%% Calculate discrete IRF depending on model
switch model
    case 'Patlak'
        IRF=PatlakIRF();
    case '2CXM'
        %% derive some parameters using notation of Sourbron (2011)
        e=PKP.vE/(PKP.vP+PKP.vE);
        E=PKP.PS_perMin/(PKP.PS_perMin+(1/100)*PKP.FP_mlPer100gPerMin);
        tauP = ((E - E*e + e)/(2*E)) * ( 1 + sqrt(1-(4*E*e*(1-E)*(1-e))/((E-E*e+e)^2)) );
        tauM = ((E - E*e + e)/(2*E)) * ( 1 - sqrt(1-(4*E*e*(1-E)*(1-e))/((E-E*e+e)^2)) );
        KP = (1/100)*PKP.FP_mlPer100gPerMin/((PKP.vP+PKP.vE)*tauM); KM = (1/100)*PKP.FP_mlPer100gPerMin/((PKP.vP+PKP.vE)*tauP);
        FPos=(1/100)*PKP.FP_mlPer100gPerMin*((tauP-1)/(tauP-tauM)); FNeg=-(1/100)*PKP.FP_mlPer100gPerMin*((tauM-1)/(tauP-tauM));
        IRF=IRF2CXM();
    otherwise
        error('Model not recognised.');
end

%% Calculate Ct by convolution
Ct_mM = conv(Cp_AIF_mM.',IRF,'full').';
Ct_mM = Ct_mM(1:N); % remove extra entries so that Ct is same length as AIF, otherwise we will predict Ct (incorrectly) after acquisition has finished


%% Functions to calculate IRF
    function IRF=PatlakIRF() % function to calculate discrete IRF by taking mean for each time point
        IRF=nan(1,N);
        IRF(1)=PKP.vP + (PKP.PS_perMin/2)*(tRes_s/60); % IRF at time zero
        IRF(2:N)=PKP.PS_perMin * (tRes_s/60); % IRF at time zero+t_res, zero+2*t_res, ...
        
        %IRF(1)=PKP.vP + (3/4)*(PKP.PS_perMin/2)*(tRes_s/60); % IRF at time zero
        %IRF(2)=(1/4)*(PKP.PS_perMin/2)*(tRes_s/60) + PKP.PS_perMin * (tRes_s/60); % IRF at time zero
        %IRF(3:N)=PKP.PS_perMin * (tRes_s/60); % IRF at time zero+t_res, zero+2*t_res, ...
    end

    function IRF=IRF2CXM()
        IRF=nan(1,N);
        IRF(1)=IRF2CXMIntegral(0,(tRes_s/60)/2); % IRF at time zero
        for iTime=2:N
            IRF(iTime)=IRF2CXMIntegral( (iTime-1-0.5)*(tRes_s/60), (iTime-1+0.5)*(tRes_s/60) ); % IRF at time zero + t_res, ... (take integral of continuous IRF function between t-t_res/2 and t+t_res/2)
        end
    end

%% Functions to calculate exact integral of IRF over any range (needed to convert IRF to a discrete function)
    function IRFInt=IRF2CXMIntegral(t1,t2)
        IRFInt = -(FPos/KP)*(exp(-t2*KP)-exp(-t1*KP)) - (FNeg/KM)*(exp(-t2*KM)-exp(-t1*KM));
    end

end