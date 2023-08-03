% set up cds_srr function
addpath('/opt/cadence/INNOVUS201/tools.lnx86/spectre/matlab/64bit');

% directory that contains the simulation outputs
directory = sprintf('%s/Cadence/%s.psf', getenv('HOME'), '8_bit_adder_static_cmos');

% set up basic parameters
Vdd = 1.2; % define vdd
numBits = 8;
% numBits = 4;
nTestBenches = 6;
%nTestCases = 8; % 2 for testing
nTestCases = 2 + 8 + 8 + 2 + 2 + 2;
startDelay = 1000;

% define period (in ps)
period_a = 4000; % A
period_clk = 4000; % CLK

% get input signals
a_0 = cds_srr(directory, 'tran-tran', '/OutA<0>', 0);
cin = cds_srr(directory, 'tran-tran', '/OutC', 0);
cout = cds_srr(directory, 'tran-tran', '/Cout_2', 0);
% Extract voltage for Cin
cin =  cin.V;
cout = cout.V;

% convert time into ps
% t_ps is an array of times that has now been normalized
t_ps = a_0.time*1e12;

% extract voltages of signals
% a = a.V;
% b = b.V;

% get output signals and put them together in a table where the i-th
% column corresponds to the 'Y(i-1)' output
s_vec = [];
a_vec = [];
b_vec = [];
for i=1:numBits
%   Concatenate the name to access the right Y(i-1) output
    signal_name = ['/S_2<', int2str(i-1), '>'];
    s = cds_srr(directory, 'tran-tran', signal_name, 0);
%   Append voltages to form y_mtx with [Y7 .. Y0]
    s_vec = [s.V s_vec];

%   Do the same for input vector A across all 8 bits
    signal_name_a = ['/OutA<', int2str(i-1), '>'];
    a = cds_srr(directory, 'tran-tran', signal_name_a, 0);
%     Append to form [A7 .. A0]
    a_vec = [a.V a_vec];

%   Do the same for input vector B across all 8 bits
    signal_name_b = ['/OutB<', int2str(i-1), '>'];
    b = cds_srr(directory, 'tran-tran', signal_name_b, 0);
    b_vec = [b.V b_vec];

end

% Expected output
% exp_y_vec = zeros(size(s_vec));
% exp_cout_vec = zeros(size(s_vec, 1));
% sample_wvf = zeros(size(s_vec));decimal_cin = (cin > Vdd/2);

% we sample the inputs from FF at the middle of a cycle
%t_ps_sample_in = startDelay + period_a/2 + (0:nTestCases)*period_a;
t_ps_sample_in = startDelay + period_clk/2 + (0:nTestCases)*period_clk;

% we sample the outputs midway after an input changes (each 2000ps),
t_ps_sample_out = startDelay + period_clk*0.75 + (0:nTestCases)*period_clk;

%% adder output

% Convert the analog output into digital signals and then into decimal numbers in an array
digital_a = (a_vec > Vdd/2);
decimal_a = bi2de(digital_a,'left-msb');
digital_b = (b_vec > Vdd/2);
decimal_b = bi2de(digital_b,'left-msb');
digital_s = (s_vec > Vdd/2);
decimal_s = bi2de(digital_s,'left-msb');

decimal_cin = (cin > Vdd/2);
decimal_cout = (cout > Vdd/2);
exp_decimal_s = decimal_a + decimal_b + decimal_cin;
% NOTE THAT MATLAB TAKES THE LSB AS BIT 1, CARRY OUT BIT IS NUMBITS + 1
exp_decimal_cout = bitget(exp_decimal_s, numBits+1);
%remove carry out bit
exp_decimal_s = bitset(exp_decimal_s, numBits+1, 0);

% Actual output
myadder_output = zeros(nTestCases);
% Expected decoder output
exp_adder_output = zeros(nTestCases);
% Actual cout
myadder_cout = zeros(nTestCases);
% Expected decoder output
exp_adder_cout = zeros(nTestCases);


%Check each one of the sampling points
err_flag = 0;
for i=1:nTestCases
    % find t_ps closest (from the right) to the t_ps_sample_in and _out
%     What does this do?
%     t_ps_idx_in get the first index corresponding to \geq sample time
    t_ps_idx_in  = find(t_ps-t_ps_sample_in(i)>=0,1);
%     t_ps_idx_out get the first actual recorded output time that is more than the sample time
    t_ps_idx_out = find(t_ps-t_ps_sample_out(i)>=0,1);
    
    % measure the outputs and declare 1 if it is greater than Vdd/2    
    myadder_output(i) = decimal_s(t_ps_idx_out);
    exp_adder_output(i) = exp_decimal_s(t_ps_idx_out);
    
    myadder_cout(i) = decimal_cout(t_ps_idx_out);
    exp_adder_cout(i) = exp_decimal_cout(t_ps_idx_out);


    if (sum(exp_adder_cout(i) ~= myadder_cout(i)) > 0 || sum(exp_adder_output(i,:) ~= myadder_output(i,:)) > 0)
        disp(['Test ' num2str(i)...
            '/' num2str(nTestCases) ...
            ' WRONG -------'...
            'Expected output for input '...
            'A=' num2str(decimal_a(t_ps_idx_in)) ...
            ' B=' num2str(decimal_b(t_ps_idx_in)) ...        
            ' C=' num2str(decimal_cout(t_ps_idx_in))...
            ' is s=' num2str(exp_adder_output(i)) ...
            ' and cout=' num2str(exp_adder_cout(i)) ...
            ' but measured output is s=' num2str(myadder_output(i))...
            ' and cout=' num2str(myadder_cout(i))...
            ]) 
        err_flag  = err_flag + 1;
    else
        disp(['Test ' num2str(i)...
            '/' num2str(nTestCases) ...
            ' CORRECT -------'...
            'Expected output for input '...
            'A=' num2str(decimal_a(t_ps_idx_in)) ...
            ' B=' num2str(decimal_b(t_ps_idx_in)) ...        
            ' C=' num2str(decimal_cout(t_ps_idx_in))...
            ' is s=' num2str(exp_adder_output(i)) ...
            ' and cout=' num2str(exp_adder_cout(i)) ...
            ' Measured output'...
            ' s=' num2str(myadder_output(i))...
            ' and cout=' num2str(myadder_cout(i))...
            ]) 
    end
end
disp(['Correct cases: ' num2str(nTestCases - err_flag) '/' num2str(nTestCases)]);
if err_flag == 0
    disp('The adder circuit has no errors :)')
end
