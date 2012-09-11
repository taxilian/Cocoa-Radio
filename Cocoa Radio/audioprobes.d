provider CocoaRadioAudio
{
	probe ringBufferFill(int, int, int);    
	probe ringBufferEmpty(int, int, int);
    
    probe audioBuffer(int, int);
    
    probe renderCallBack(int);
    probe dataReceived(int);
};